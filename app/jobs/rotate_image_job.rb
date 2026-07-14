# frozen_string_literal: true

# Rotates/mirrors an image outside the request cycle. Replaces the old
# bare `system("script/rotate_image ... &")` fire-and-forget. #rotate
# ends by re-running Image::Processor#process, which resizes and
# recomputes the perceptual hash inline (#4796) -- so a rotation rehashes
# the image for free -- then TransferImagesJob gets the rotated files
# onto the image server(s), same as any other processing event.
class RotateImageJob < ApplicationJob
  queue_as(:default)

  def perform(image_id, ext, orientation)
    image = Image.find_by(id: image_id)
    return unless image

    Image::Processor.new(image: image, ext: ext).rotate(orientation)
    TransferImagesJob.perform_later(image_ids: [image_id])
  end
end
