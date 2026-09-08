# frozen_string_literal: true

# Displays an image's camera metadata in the observation form.
#
# For the observation's editable images: EXIF GPS/date, file name/size,
# and a button to transfer the EXIF onto the observation.
#
# For a read-only reflection (sibling) image (`read_only: true`): the
# same EXIF display plus the image's immutable copyright/license, a note
# that it can only be changed at the source, and a link to the source
# observation. "Use this info" appears only when there is a location or
# a differing date to adopt onto the primary (#5317).
#
# @example
#   render Components::Form::CameraInfo.new(
#     img_id: 123, lat: 45.5231, lng: -122.6765, alt: 100,
#     date: "2024-01-15", file_name: "IMG_1234.jpg", file_size: "2.5 MB"
#   )
class Components::Form::CameraInfo < Components::Base
  # All value props are nilable to handle missing data.
  prop :img_id, _Nilable(String), &:to_s
  # GPS coordinates arrive as Float/Integer/String; coerce to Float
  # (Phlex renders them as strings).
  prop :lat, _Nilable(_Union(String, Integer, Float)) do |v|
    v.presence&.to_f
  end
  prop :lng, _Nilable(_Union(String, Integer, Float)) do |v|
    v.presence&.to_f
  end
  prop :alt, _Nilable(_Union(String, Integer, Float)) do |v|
    v.presence&.to_f
  end
  prop :date, _Nilable(String), default: ""
  prop :file_name, _Nilable(String), default: ""
  prop :file_size, _Nilable(String), default: ""
  # Read-only reflection (sibling) image: show immutable metadata + a
  # source link instead of editable affordances.
  prop :read_only, _Boolean, default: false
  prop :copyright_holder, _Nilable(String), default: nil
  prop :license_name, _Nilable(String), default: nil
  prop :source_url, _Nilable(String), default: nil
  # The image's date differs from the primary's, so "Use this info" is
  # worth offering even without an EXIF location.
  prop :date_differs, _Boolean, default: false

  def view_template
    div(
      id: "camera_info_#{@img_id}",
      class: "well well-sm position-relative"
    ) do
      label(for: "camera_info_#{@img_id}") { panel_label }
      render_reflection_note if @read_only
      render_exif_info
      render_immutable_info if @read_only
      render_file_info
    end
  end

  def render_exif_info
    div(class: "form-group") do
      render_date_field
      render_gps_field
      render_transfer_button
    end
  end

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

  def render_transfer_button
    transfer_exif_button
  end

  # Immutable, source-owned values for a reflection image.
  def render_immutable_info
    render_labeled(:copyright_holder.ti, @copyright_holder,
                   "reflection_copyright")
    render_labeled(:license.ti, @license_name, "reflection_license")
    render_source_link
  end

  def render_file_info
    div(class: "form-group mb-0 overflow-hidden") do
      render_filename if @file_name.present?
      render_filesize if @file_size.present?
    end
  end

  def render_filename
    div do
      strong { append_colon(:image_file_name.l) }
      span(class: "file_name") { @file_name }
    end
  end

  def render_filesize
    div do
      strong { append_colon(:image_file_size.l) }
      span(class: "file_size") { @file_size }
    end
  end

  private

  def panel_label
    @read_only ? :image_reflection_info.l : :image_camera_info.l
  end

  def render_reflection_note
    Help(content: :image_reflection_readonly_note.l,
         class: "reflection_readonly_note")
  end

  def render_labeled(label_text, value, css_class)
    return if value.blank?

    div do
      strong { append_colon(label_text) }
      span(class: css_class) { value }
    end
  end

  def render_source_link
    return if @source_url.blank?

    div do
      Link(type: :external, content: :image_reflection_source_link.l,
           path: @source_url, class: "reflection_source_link")
    end
  end

  def render_gps_info
    span(class: "exif_gps") do
      # Always render all three fields so JavaScript can find and populate them
      [:lat, :lng, :alt].each_with_index do |field, index|
        value = instance_variable_get("@#{field}")
        has_value = value.present?

        # Wrap each field so we can hide it when empty
        wrapper_class = class_names("exif_#{field}_wrapper",
                                    "d-none": !has_value)

        span(class: wrapper_class) do
          # Add comma before non-first fields
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
