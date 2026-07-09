# frozen_string_literal: true

# Resizes, reorients, and transfers an uploaded image's files outside the
# request cycle. GPS stripping (if any) already happened synchronously in
# Image#process_image before this was enqueued -- see that method and
# Image::Processor.strip_original_gps for why.
class ProcessImageJob < ApplicationJob
  queue_as(:default)

  def perform(image_id, ext, set_size)
    image = Image.find_by(id: image_id)
    return unless image

    Image::Processor.new(image: image, ext: ext, set_size: set_size).process
    ImageDhashJob.perform_later(image_id)
  end
end
