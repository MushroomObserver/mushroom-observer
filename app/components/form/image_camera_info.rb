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
  include Phlex::Rails::Helpers::LabelTag

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
      id: "camera_info_#{img_id}",
      class: "well well-sm position-relative"
    ) do
      label(for: "camera_info_#{img_id}") { :image_camera_info.l }
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
      unsafe_raw(helpers.carousel_exif_to_image_date_button(date: date))
    end
  end

  def render_gps_field
    div do
      render_gps_info
      render_no_gps_message
    end
  end

  def render_transfer_button
    unsafe_raw(helpers.carousel_transfer_exif_button(
                 has_exif: date.present? || lat.present?
               ))
  end

  def render_file_info
    div(class: "form-group mb-0 overflow-hidden") do
      render_filename if file_name.present?
      render_filesize
    end
  end

  def render_filename
    div do
      strong { "#{:image_file_name.l}: " }
      span(class: "file_name") { file_name }
    end
  end

  def render_filesize
    div do
      strong { "#{:image_file_size.l}: " }
      span(class: "file_size") { file_size }
    end
  end

  private

  def render_gps_info
    span(class: "exif_gps") do
      parts = [
        build_gps_part(:LAT, lat, "exif_lat"),
        build_gps_part(:LNG, lng, "exif_lng"),
        build_alt_part
      ]
      plain(parts.join(", "))
    end
  end

  def build_gps_part(label_key, value, css_class)
    strong_tag = helpers.tag.strong("#{label_key.l}: ")
    span_tag = helpers.tag.span(value, class: css_class)
    strong_tag + span_tag
  end

  def build_alt_part
    strong_tag = helpers.tag.strong("#{:ALT.l}: ")
    span_tag = helpers.tag.span(alt, class: "exif_alt")
    "#{strong_tag}#{span_tag} m"
  end

  def render_no_gps_message
    span(class: "exif_no_gps d-none") { :image_no_geolocation.l }
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
