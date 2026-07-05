# frozen_string_literal: true

# Computes and stores an image's perceptual hash (Image::Dhash) outside the
# request cycle — hashing decodes the image with ImageMagick, too slow for
# the upload request itself (#4585/#4673). Recomputes unconditionally, so
# it also serves post-transform rehashing.
class ImageDhashJob < ApplicationJob
  queue_as(:default)

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image

    image.compute_dhash!
  end
end
