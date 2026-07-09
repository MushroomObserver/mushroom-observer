# frozen_string_literal: true

# Nulls out Observation.thumb_image_id when it doesn't match any attached
# image anywhere (i.e. `image_id` doesn't appear in any observation_images
# row at all - not scoped to this specific observation's own images, a
# faithful port of the original script's looser global check).
class CheckForOrphanedThumbnailsJob < ApplicationJob
  queue_as :maintenance

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose

    query = orphaned_thumbnails
    count = query.count
    return if count.zero?

    # Only materialize the actual rows (an extra query) when verbose -
    # the common non-verbose run just needs the count.
    rows = query.pluck(:id, :thumb_image_id) if @verbose
    query.update_all(thumb_image_id: nil) unless @dry_run
    log("NULLING thumb_image_id on #{count} observation(s)" \
        "#{rows_suffix(rows)}#{dry_run_note}")
  end

  private

  def orphaned_thumbnails
    Observation.where.not(thumb_image_id: nil).
      where.not(thumb_image_id: attached_image_ids)
  end

  def attached_image_ids
    ObservationImage.select(:image_id).distinct
  end

  def rows_suffix(rows)
    rows ? " #{rows.inspect}" : ""
  end

  def dry_run_note
    @dry_run ? " (dry run)" : ""
  end
end
