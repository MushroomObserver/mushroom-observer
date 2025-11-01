# frozen_string_literal: true

# Displays EXIF camera metadata for an image in the observation form.
#
# Shows:
# - GPS coordinates (lat, lng, alt)
# - Date taken
# - File name and size
# - Button to transfer EXIF data to observation form
#
# @example
#   render Components::Form::ImageCameraInfo.new(
#     img_id: 123,
#     lat: "45.5231",
#     lng: "-122.6765",
#     alt: "100",
#     date: "2024-01-15",
#     file_name: "IMG_1234.jpg",
#     file_size: "2.5 MB"
#   )
class Components::Form::ImageCameraInfo < Components::Base
  include Phlex::Rails::Helpers::ClassNames
  include Phlex::Rails::Helpers::LinkTo

  # Properties
  prop :img_id, Integer, &:to_i
  prop :lat, String, default: ""
  prop :lng, String, default: ""
  prop :alt, String, default: ""
  prop :date, String, default: ""
  prop :file_name, String, default: ""
  prop :file_size, String, default: ""

  def view_template
    div(
      id: "camera_info_#{@img_id}",
      class: "well well-sm position-relative"
    ) do
      label(for: "camera_info_#{@img_id}") { :image_camera_info.l }
      render_exif_info
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
      strong { "#{:DATE.l}: " }
      exif_to_image_date_button
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

  def render_file_info
    div(class: "form-group mb-0 overflow-hidden") do
      render_filename if @file_name.present?
      render_filesize
    end
  end

  def render_filename
    div do
      strong { "#{:image_file_name.l}: " }
      span(class: "file_name") { @file_name }
    end
  end

  def render_filesize
    div do
      strong { "#{:image_file_size.l}: " }
      span(class: "file_size") { @file_size }
    end
  end

  private

  def render_gps_info
    parts = [
      build_gps_part(:LAT, @lat, "exif_lat"),
      build_gps_part(:LNG, @lng, "exif_lng"),
      build_alt_part
    ]
    span(class: "exif_gps") { parts.join(", ") }
  end

  def build_gps_part(label_key, value, css_class)
    [
      strong { "#{label_key.l}:" },
      span(class: css_class) { value }
    ].join(" ")
  end

  def build_alt_part
    [
      strong { "#{:ALT.l}:" },
      span(class: "exif_alt") { @alt }
    ].join(" ")
  end

  def render_no_gps_message
    span(class: "exif_no_gps d-none") { :image_no_geolocation.l }
  end

  def exif_to_image_date_button
    link_to(
      "#",
      data: { action: "form-exif#exifToImageDate:prevent" }
    ) do
      span(class: "exif_date") { @date }
    end
  end

  def transfer_exif_button
    has_exif = @date.present? || @lat.present?
    button_classes = class_names("btn btn-default",
                                 "use_exif_btn btn-sm ab-top-right",
                                 "d-none": !has_exif)

    button(
      type: "button",
      class: button_classes,
      data: { form_exif_target: "useExifBtn",
              action: "form-exif#transferExifToObs:prevent" }
    ) do
      span(class: "when-enabled") { :image_use_exif.l }
      span(class: "when-disabled") { :image_exif_copied.l }
    end
  end
end
