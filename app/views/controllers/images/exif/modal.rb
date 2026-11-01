# frozen_string_literal: true

module Views::Controllers::Images
  module EXIF
    # Turbo-stream lightbox modal triggered from
    # `Components::ImageFragment::EXIFLink`. A Phlex view wrapper is
    # required because controller `render`
    # doesn't thread the block through to a Phlex component's
    # `view_template(&block)` — every `Components::Modal` caller in this
    # codebase goes through a Phlex view, not a controller render call.
    #
    # The EXIF header itself loads lazily: enqueues EXIFDataJob and
    # subscribes to its broadcast in this same render, rather than
    # fetching a separate Turbo Frame URL, for the same race-avoiding
    # reason as Components::Form::CameraInfo (see EXIFGeocodeJob).
    class Modal < Views::Base
      include Phlex::Rails::Helpers::TurboStreamFrom

      prop :image, ::Image

      def view_template
        EXIFDataJob.enqueue_for(@image.id)

        # Must stay `render(::Components::Modal.new(...))`, not bare
        # `Modal(...)` Kit syntax -- this view class is itself named
        # `Modal`, so Kit's constant lookup would recurse into itself
        # instead of resolving `Components::Modal` (see commit
        # 33fdc952e5 for the same bug with a view class named `Table`).
        render(::Components::Modal.new(
                 id: "modal_image_exif_#{@image.id}",
                 title: :exif_data_for_image.t(image: @image.id),
                 user: current_user
               )) do |m|
          m.with_body do
            turbo_stream_from("exif_data_#{@image.id}")
            turbo_frame_tag("exif_data_frame_#{@image.id}") do
              Icon(type: :spinner, class: "spinner-right")
            end
          end
        end
      end
    end
  end
end
