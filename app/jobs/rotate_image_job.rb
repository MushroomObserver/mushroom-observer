# frozen_string_literal: true

# Rotates/mirrors an image outside the request cycle. Replaces the old
# bare `system("script/rotate_image ... &")` fire-and-forget: since this
# runs as a real, awaited job, ImageDhashJob can be enqueued right after
# rotate finishes instead of guessing at a fixed delay.
class RotateImageJob < ApplicationJob
  queue_as(:default)

  def perform(image_id, ext, orientation)
    image = Image.find_by(id: image_id)
    return unless image

    Image::Processor.new(image: image, ext: ext).rotate(orientation)
    ImageDhashJob.perform_later(image_id)
  end
end
