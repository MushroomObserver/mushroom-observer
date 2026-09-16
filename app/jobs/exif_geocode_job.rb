# frozen_string_literal: true

# Reads an image's EXIF GPS/date data and broadcasts the result into
# Components::Form::CameraInfo's Turbo Frame, off the web request
# that renders the observation edit page.
#
# Image#read_exif_geocode shells out to exiftool (locally, or fetches
# the original over HTTP first for a transferred image). Running that
# inline in a controller action ties up a web worker for the whole
# call -- production runs single-threaded Puma workers, so one slow
# image host could tie up several of the site's few worker slots at
# once. See issue #5369.
class EXIFGeocodeJob < ApplicationJob
  queue_as(:default)

  # CameraInfo enqueues this job directly and subscribes to the
  # broadcast in the same render pass, with no separate Turbo Frame
  # fetch to race against. The one remaining race: the page's Action
  # Cable subscription needs a moment to connect after the response
  # reaches the browser. A fast local image can otherwise finish
  # before that connection exists, and a broadcast with no live
  # subscriber is simply lost -- Turbo Streams don't queue for late
  # subscribers. This delay is cheap insurance for that case, and
  # irrelevant for the slow/transferred case this job exists for.
  DELAY = 1.second

  def self.enqueue_for(image_id, read_only:, date_differs:)
    set(wait: DELAY).perform_later(image_id, read_only: read_only,
                                             date_differs: date_differs)
  end

  def perform(image_id, read_only:, date_differs:)
    image = Image.find_by(id: image_id)
    return unless image

    broadcast_geocode(image, read_only: read_only, date_differs: date_differs)
  end

  private

  def broadcast_geocode(image, read_only:, date_differs:)
    data = image.read_exif_geocode(hide_gps: false) || {}
    html = render_geocode_view(image, data, read_only: read_only,
                                            date_differs: date_differs)
    image.broadcast_replace_to(
      exif_geocode_stream(image.id),
      target: "camera_info_exif_#{image.id}",
      html: html
    )
  end

  def render_geocode_view(image, data, read_only:, date_differs:)
    ApplicationController.renderer.render(
      Views::Controllers::Images::EXIFGeocode::Show.new(
        img_id: image.id.to_s,
        lat: data[:lat],
        lng: data[:lng],
        alt: data[:alt],
        date: data[:date] || SimpleDate.from_date(image.when),
        date_differs: date_differs,
        read_only: read_only
      ),
      layout: false
    )
  end

  # A plain string, not [image, :exif_geocode] -- Components::Form::
  # CameraInfo only has the image id, not a loaded Image, when it
  # renders the matching turbo_stream_from subscription. Both sides
  # need to build the identical stream name.
  def exif_geocode_stream(image_id)
    "exif_geocode_#{image_id}"
  end
end
