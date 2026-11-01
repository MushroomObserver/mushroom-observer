# frozen_string_literal: true

# Reads an image's full EXIF header and broadcasts the result into
# the lightbox "Show EXIF Header" modal's Turbo Frame, off the web
# request that opens the modal.
#
# Image#read_exif_data shells out to exiftool (locally, or fetches
# the original over HTTP first for a transferred image) -- the same
# slow, worker-tying-up operation EXIFGeocodeJob backgrounds for the
# observation edit page. See issue #5369.
class EXIFDataJob < ApplicationJob
  queue_as(:default)

  # The modal enqueues this job directly and subscribes to its
  # broadcast in the same render, with no separate Turbo Frame fetch
  # to race against (see EXIFGeocodeJob for why that matters). The
  # delay is cheap insurance against a fast job broadcasting before
  # the page's Action Cable subscription has connected.
  DELAY = 1.second

  def self.enqueue_for(image_id)
    set(wait: DELAY).perform_later(image_id)
  end

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image

    broadcast_data(image)
  end

  private

  def broadcast_data(image)
    data, status, result = image.read_exif_data
    html = render_data_view(image, data, status, result)
    image.broadcast_replace_to(
      exif_data_stream(image.id),
      target: "exif_data_frame_#{image.id}",
      html: html
    )
  end

  def render_data_view(image, data, status, result)
    ApplicationController.renderer.render(
      Views::Controllers::Images::EXIF::DataFrame.new(
        img_id: image.id.to_s,
        data: data,
        success: status.success?,
        error_text: result
      ),
      layout: false
    )
  end

  # A plain string, not [image, :exif_data] -- the modal only has the
  # image id, not a loaded Image, when it renders the matching
  # turbo_stream_from subscription. Both sides need to build the
  # identical stream name.
  def exif_data_stream(image_id)
    "exif_data_#{image_id}"
  end
end
