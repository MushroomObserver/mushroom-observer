# frozen_string_literal: true

# Displays an image's camera metadata in the observation form.
#
# For the observation's editable images: EXIF GPS/date, file name/size,
# and a button to transfer the EXIF onto the observation.
#
# For an occurrence sibling's image (`read_only: true`): the same EXIF
# display plus the image's immutable copyright/license and a note saying
# where it can be changed. `reflection: true` words that note for an
# image mirroring an imported source; the link to that source follows
# `source_url`, not `reflection`. "Use this info" appears only when
# there is a location or a differing date to adopt onto the primary
# (#5317).
#
# @example
#   render Components::Form::CameraInfo.new(
#     img_id: 123, lat: 45.5231, lng: -122.6765, alt: 100,
#     date: "2024-01-15", file_name: "IMG_1234.jpg", file_size: "2.5 MB"
#   )
class Components::Form::CameraInfo < Components::Base
  include Components::Form::CameraInfoEXIFFields
  include Phlex::Rails::Helpers::TurboStreamFrom

  # True for a freshly-uploaded image, where client-side JS
  # (form-exif_controller.js) fills the date/GPS fields in from the
  # local file. False for a saved image, where the fields load lazily
  # from the server instead (#5369).
  prop :upload, _Boolean, default: false
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
  # Occurrence sibling image: show immutable metadata instead of
  # editable affordances.
  prop :read_only, _Boolean, default: false
  # The sibling mirrors an imported source (an iNat reflection) rather
  # than being another editable observation of the same specimen. Only
  # a reflection's metadata is owned elsewhere, so only a reflection
  # gets the imported-source wording.
  prop :reflection, _Boolean, default: false
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
      render_read_only_note if @read_only
      render_exif_info
      render_immutable_info if @read_only
      render_file_info
    end
  end

  # A freshly-uploaded image renders the fields directly, so
  # form-exif_controller.js can fill them in from the local file. A
  # saved image loads them lazily from the server instead, since
  # reading EXIF data can be slow (#5369).
  def render_exif_info
    if @upload
      render_eager_exif_fields
    else
      render_lazy_exif_frame
    end
  end

  def render_eager_exif_fields
    div(class: "form-group") do
      render_date_field
      render_gps_field
      render_transfer_button
    end
  end

  # Enqueues EXIFGeocodeJob directly and subscribes to its broadcast
  # in this same render, rather than fetching a separate Turbo Frame
  # URL. A frame fetch and a broadcast are two independent delivery
  # paths to the same target; if the job finishes before the frame's
  # fetch response arrives, that response would overwrite the
  # already-delivered content with a stale loading spinner. Enqueuing
  # here and rendering only the spinner directly removes the second
  # path instead of racing it. See EXIFGeocodeJob for the one
  # remaining timing concern this doesn't solve.
  def render_lazy_exif_frame
    EXIFGeocodeJob.enqueue_for(@img_id, read_only: @read_only,
                                        date_differs: @date_differs)
    turbo_stream_from("exif_geocode_#{@img_id}")
    turbo_frame_tag("camera_info_exif_#{@img_id}", class: "form-group") do
      Icon(type: :spinner, class: "spinner-right")
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
    return :image_camera_info.l unless @read_only

    @reflection ? :image_reflection_info.l : :image_sibling_info.l
  end

  def render_read_only_note
    Help(content: read_only_note, class: "reflection_readonly_note")
  end

  def read_only_note
    return :image_reflection_readonly_note.l if @reflection

    :image_sibling_readonly_note.l
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
end
