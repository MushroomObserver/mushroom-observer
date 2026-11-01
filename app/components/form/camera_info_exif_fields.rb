# frozen_string_literal: true

# Renders the date, GPS, and "Use this info" fields shared by two
# callers. Components::Form::CameraInfo uses it directly for a
# freshly-uploaded image, where client-side JS fills the fields in.
# Views::Controllers::Images::ExifGeocode::Show uses it for a saved
# image, where the server already read the EXIF data. See issue
# #5369 for why the saved-image case moved off the page's request.
#
# The including class needs `@lat`, `@lng`, `@alt`, `@date`,
# `@date_differs`, and `@read_only` instance variables.
module Components::Form::CameraInfoEXIFFields
  private

  def render_date_field
    div do
      strong { append_colon(:date.ti) }
      if @read_only
        whitespace
        span(class: "exif_date") { @date }
      else
        exif_to_image_date_button
      end
    end
  end

  def render_gps_field
    div do
      render_gps_info
      render_no_gps_message
    end
  end

  # Always render all three fields so JavaScript can find and
  # populate them.
  def render_gps_info
    span(class: "exif_gps") do
      [:lat, :lng, :alt].each_with_index do |field, index|
        value = instance_variable_get("@#{field}")
        has_value = value.present?
        wrapper_class = class_names("exif_#{field}_wrapper",
                                    "d-none": !has_value)

        span(class: wrapper_class) do
          plain(", ") if index.positive?
          render_gps_part(field, value)
        end
      end
    end
  end

  def render_gps_part(field, value)
    label_key = field.upcase
    css_class = "exif_#{field}"

    strong { append_colon(label_key.l) }
    span(class: css_class) { value }
  end

  def render_no_gps_message
    span(class: "exif_no_gps d-none") { :image_no_geolocation.l }
  end

  def exif_to_image_date_button
    Link(
      type: :get,
      name: @date,
      target: "#",
      data: { action: "form-exif#exifToImageDate:prevent" }
    ) do
      span(class: "exif_date") { @date }
    end
  end

  def transfer_exif_button
    Button(
      size: :sm,
      class: class_names("use_exif_btn ab-top-right",
                         "d-none": !show_transfer_button?),
      data: { form_exif_target: "useExifBtn",
              action: "form-exif#transferExifToObs:prevent" }
    ) do
      span(class: "when-enabled") { :image_use_exif.l }
      span(class: "when-disabled") { :image_exif_copied.l }
    end
  end

  def show_transfer_button?
    return @lat.present? || @date_differs if @read_only

    @date.present? || @lat.present?
  end
end
