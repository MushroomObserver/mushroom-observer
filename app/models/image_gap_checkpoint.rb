# frozen_string_literal: true

# Singleton high-water mark for ImageGapDetectorJob: the highest image id
# whose derived renditions have been verified present on the image
# server(s). The gap detector only examines images past this mark and
# advances it as it verifies them, so an already-clean image is never
# re-scanned (nothing removes a derived size from the server after
# transfer -- only the original is later archived, and the detector does
# not treat a missing original as a gap).
class ImageGapCheckpoint < ApplicationRecord
  # The one row, created on first access. Defaults last_verified_image_id
  # to the current max image id so an *un*initialized checkpoint is a safe
  # no-op (examines nothing) rather than a full-history rescan. Backfill an
  # earlier window explicitly with .reset_to.
  def self.instance
    first || create!(last_verified_image_id: Image.maximum(:id) || 0)
  end

  def self.last_verified_image_id
    instance.last_verified_image_id
  end

  # Move the mark forward only (never backward).
  def self.advance_to(image_id)
    record = instance
    return if image_id <= record.last_verified_image_id

    record.update!(last_verified_image_id: image_id)
  end

  # Explicitly (re)set the mark -- used to initialize the checkpoint to a
  # known-verified id on deploy, e.g.
  # `bin/rails runner "ImageGapCheckpoint.reset_to(2034578)"`.
  def self.reset_to(image_id)
    instance.update!(last_verified_image_id: image_id)
  end
end
