# frozen_string_literal: true

module Views::Controllers::Images
  module EXIFGeocode
    # Turbo Frame content for Components::Form::CameraInfo's date/GPS
    # fields and "Use this info" button, for a saved image. See issue
    # #5369 for why this loads lazily instead of at page-render time.
    #
    # The frame carries `data-geocode` and `data-exif-date` so
    # `form-exif_controller.js` can copy them onto the carousel
    # item once this loads, keeping "Use this info" working for
    # sibling images the same way it already works for the primary.
    class Show < Views::Base
      include Components::Form::CameraInfoEXIFFields

      prop :img_id, ::String
      # read_exif_geocode returns alt as an Integer (rounded), lat/lng
      # as Float -- accept either so callers don't need to coerce.
      prop :lat, _Nilable(_Union(Integer, Float)), default: nil
      prop :lng, _Nilable(_Union(Integer, Float)), default: nil
      prop :alt, _Nilable(_Union(Integer, Float)), default: nil
      prop :date, _Nilable(::SimpleDate), default: nil
      prop :date_differs, _Boolean, default: false
      prop :read_only, _Boolean, default: false

      def view_template
        # CameraInfoEXIFFields reads `@date` directly, expecting a
        # display string (it's shared with Components::Form::CameraInfo,
        # whose `@date` is a plain string) -- capture the SimpleDate
        # for the frame's JSON attribute first, then shadow `@date`
        # with its display form for the shared module's rendering.
        simple_date = @date
        @date = simple_date&.to_display
        turbo_frame_tag(frame_id, class: "form-group",
                                  data: frame_data(simple_date)) do
          render_date_field
          render_gps_field
          render_transfer_button
        end
      end

      private

      def frame_id
        "camera_info_exif_#{@img_id}"
      end

      def render_transfer_button
        transfer_exif_button
      end

      def frame_data(simple_date)
        {
          geocode: geocode_json,
          exif_date: simple_date&.to_json,
          action: "turbo:frame-load->form-exif#syncItemExif"
        }
      end

      def geocode_json
        return "" if @lat.blank? || @lng.blank?

        { lat: @lat, lng: @lng, alt: @alt }.to_json
      end
    end
  end
end
