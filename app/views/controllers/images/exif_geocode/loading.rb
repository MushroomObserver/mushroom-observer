# frozen_string_literal: true

module Views::Controllers::Images
  module EXIFGeocode
    # Initial content for Components::Form::CameraInfo's lazy Turbo
    # Frame. EXIFGeocodeJob replaces this with the frame's content
    # once it finishes reading the image's EXIF data. See issue
    # #5369.
    class Loading < Views::Base
      prop :img_id, ::String

      def view_template
        turbo_frame_tag("camera_info_exif_#{@img_id}", class: "form-group") do
          Icon(type: :spinner, class: "spinner-right")
        end
      end
    end
  end
end
