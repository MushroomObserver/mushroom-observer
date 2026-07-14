# frozen_string_literal: true

# Computes and stores an image's perceptual hash (Image::Dhash) outside the
# request cycle — hashing decodes the image with ImageMagick, too slow for
# the upload request itself (#4585/#4673). Recomputes unconditionally, so
# it also serves post-transform rehashing.
class ImageDhashJob < ApplicationJob
  queue_as(:default)

  # `process_image` enqueues this job as soon as it backgrounds
  # script/process_image (fire-and-forget, does not wait for the resize/
  # transfer to finish) -- so no rendition may be available yet
  # (Image#dhash_source_ready?, #4799). Not urgent, so reschedule with
  # exponential backoff instead of hashing a placeholder URL. Six
  # attempts spans 30s + 1m + 2m + 4m + 8m ≈ 15 minutes, comfortably
  # longer than script/process_image ever takes; give up silently past
  # that rather than retrying forever (e.g. the transfer permanently
  # failed).
  MAX_ATTEMPTS = 6
  INITIAL_WAIT = 30.seconds

  def perform(image_id, attempt: 1)
    image = Image.find_by(id: image_id)
    return unless image

    if image.dhash_source_ready?
      image.compute_dhash!
    elsif attempt < MAX_ATTEMPTS
      reschedule(image_id, attempt)
    end
  end

  private

  def reschedule(image_id, attempt)
    wait = INITIAL_WAIT * (2**(attempt - 1))
    ImageDhashJob.set(wait: wait).perform_later(image_id, attempt: attempt + 1)
  end
end
