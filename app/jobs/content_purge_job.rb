# frozen_string_literal: true

# Runs a ContentPurge (#5521); ContentPurge::Plan says what goes. Deletes
# database rows only: the files on the image server and in archive
# storage stay.
#
# The plan is read from the database each run, so a run cut short (a
# worker restart) is finished by running again. The emails go out once,
# before anything is deleted.
#
# Nothing here bumps an observation's updated_at or its log's date, so a
# purge does not push thousands of observations to the top of the
# activity feed.
class ContentPurgeJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(purge)
    @purge = purge
    @plan = purge.plan
    @actor = purge.user || User.admin
    run
  rescue StandardError => e
    purge.update(state: :failed, error: e.message, ended_at: Time.zone.now)
    log("ContentPurge #{purge.id} failed: #{e.class}: #{e.message}")
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
    ContentPurge::Notices.new(@plan, target_user: @purge.target_user).
      by_receiver.each do |receiver, entries|
        ContentPurgeMailer.build(receiver: receiver, purge: @purge,
                                 entries: entries.map(&:to_h)).deliver_later
      end
    @purge.update!(notified_at: Time.zone.now)
  end

  # Before the images go, while the plan can still tell which imported
  # observations they leave empty.
  def convert_placeholders
    ids = @plan.placeholder_observations.where(placeholder: false).pluck(:id)
    ids.each_slice(BATCH_SIZE) do |slice|
      count = Observation.where(id: slice).
              update_all(placeholder: true, notes: Observation.no_notes)
      @purge.increment!(:placeholder_count, count)
    end
  end

  # The observations stay as ordinary ones, with the facts but no notes.
  def clear_native_notes
    @plan.native_observations.pluck(:id).each_slice(BATCH_SIZE) do |slice|
      count = Observation.where(id: slice).
              update_all(notes: Observation.no_notes)
      @purge.increment!(:cleared_notes_count, count)
    end
  end

  # Observations are detached first, so Image#update_thumbnails
  # (before_destroy) only refills glossary terms and profiles.
  def destroy_images
    @plan.images.pluck(:id).each_slice(BATCH_SIZE) do |slice|
      images = Image.where(id: slice).strict_loading(false).to_a
      images.each do |image|
        image.current_user = @actor
        image.log_destroy(touch: false)
      end
      detach_from_observations(slice)
      images.each(&:destroy)
      @purge.increment!(:deleted_image_count, images.size)
    end
  end

  def detach_from_observations(image_ids)
    obs_ids = ObservationImage.where(image_id: image_ids).
              distinct.pluck(:observation_id)
    ObservationImage.where(image_id: image_ids).delete_all
    Observation.where(thumb_image_id: image_ids).strict_loading(false).
      each do |obs|
        obs.update_columns(thumb_image_id: obs.next_thumb_image&.id)
      end
    expire_activity_boxes(obs_ids)
  end

  # The activity feed caches each box under its log's updated_at, which
  # stays put, so a box would keep showing the deleted thumbnail.
  def expire_activity_boxes(obs_ids)
    RssLog.where(observation_id: obs_ids).find_each do |rss_log|
      I18n.available_locales.each do |locale|
        Rails.cache.delete(
          Components::Matrix::Table.cache_key_for(rss_log, locale)
        )
      end
    end
  end
end
