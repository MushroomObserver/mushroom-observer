# frozen_string_literal: true

# Runs an ImagePurge (#5521); ImagePurge::Plan says what goes. Deletes
# database rows only: the files on the image server and in archive
# storage stay.
#
# The plan is read from the database each run, so a run cut short (a
# worker restart) is finished by running again. The emails go out once,
# before anything is deleted.
class ImagePurgeJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(purge)
    @purge = purge
    @plan = purge.plan
    @actor = purge.user || User.admin
    run
  rescue StandardError => e
    purge.update(state: :failed, error: e.message, ended_at: Time.zone.now)
    log("ImagePurge #{purge.id} failed: #{e.class}: #{e.message}")
  end

  private

  def run
    start
    notify unless @purge.notified_at
    convert_placeholders
    clear_native_notes
    destroy_images
    @purge.update!(state: :done, ended_at: Time.zone.now)
  end

  def start
    attrs = { state: :running }
    attrs[:image_count] = @plan.image_count if @purge.pending?
    @purge.update!(attrs)
  end

  def notify
    ImagePurge::Notices.new(@plan, target_user: @purge.target_user).
      by_receiver.each do |receiver, entries|
        ImagePurgeMailer.build(receiver: receiver, purge: @purge,
                               entries: entries.map(&:to_h)).deliver_later
      end
    @purge.update!(notified_at: Time.zone.now)
  end

  # Before the images go, while the plan can still tell which imported
  # observations they leave empty.
  def convert_placeholders
    ids = @plan.placeholder_observations.where(placeholder: false).pluck(:id)
    ids.each_slice(BATCH_SIZE) do |slice|
      Observation.where(id: slice).strict_loading(false).each do |obs|
        obs.update_columns(placeholder: true, notes: Observation.no_notes,
                           updated_at: Time.zone.now)
      end
      @purge.increment!(:placeholder_count, slice.size)
    end
  end

  # The observations stay as ordinary ones, with the facts but no notes.
  def clear_native_notes
    @plan.native_observations.pluck(:id).each_slice(BATCH_SIZE) do |slice|
      count = Observation.where(id: slice).count do |obs|
        next false if obs.notes.blank?

        obs.update_columns(notes: Observation.no_notes,
                           updated_at: Time.zone.now)
      end
      @purge.increment!(:cleared_notes_count, count)
    end
  end

  # Image#update_thumbnails (before_destroy) refills every observation,
  # glossary term and profile whose thumbnail pointed at the image.
  def destroy_images
    @plan.images.pluck(:id).each_slice(BATCH_SIZE) do |slice|
      count = Image.where(id: slice).strict_loading(false).count do |image|
        image.current_user = @actor
        image.log_destroy
        image.destroy
      end
      @purge.increment!(:deleted_image_count, count)
    end
  end
end
