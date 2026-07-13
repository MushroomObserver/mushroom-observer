# frozen_string_literal: true

# Resizes, reorients, and transfers an uploaded image's files outside the
# request cycle. GPS stripping (if any) already happened synchronously in
# Image#process_image before this was enqueued -- see that method and
# Image::Processor.strip_original_gps for why.
class ProcessImageJob < ApplicationJob
  queue_as(:default)

  # Returns whether the transfer completed cleanly (no dangling #errors on
  # the processor) -- meaningless to `perform_later` callers, but read
  # directly by Image#process_image's `synchronous: true` callers (API
  # uploads, which can't see a later background failure any other way -
  # see that method for why). ImageDhashJob is enqueued unconditionally
  # either way: a remote transfer failure doesn't invalidate the local
  # file's perceptual hash.
  def perform(image_id, ext, set_size)
    image = Image.find_by(id: image_id)
    return unless image

    processor = Image::Processor.new(image: image, ext: ext,
                                     set_size: set_size)
    processor.process
    ImageDhashJob.perform_later(image_id)
    processor.errors.empty?
  end
end
