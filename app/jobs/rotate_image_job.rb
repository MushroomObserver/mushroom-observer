# frozen_string_literal: true

# Rotates/mirrors an image outside the request cycle. Replaces the old
# bare `system("script/rotate_image ... &")` fire-and-forget: since this
# runs as a real, awaited job, ImageDhashJob can be enqueued right after
# rotate finishes instead of guessing at a fixed delay. #rotate ends by
# re-running Image::Processor#process, which only resizes now (see
# #4791) -- TransferImagesJob gets the rotated files onto the image
# server(s), same as any other processing event.
class RotateImageJob < ApplicationJob
  queue_as(:default)

  def perform(image_id, ext, orientation)
    image = Image.find_by(id: image_id)
    return unless image

    Image::Processor.new(image: image, ext: ext).rotate(orientation)
    TransferImagesJob.perform_later(image_ids: [image_id])
    ImageDhashJob.perform_later(image_id)
  end
end
