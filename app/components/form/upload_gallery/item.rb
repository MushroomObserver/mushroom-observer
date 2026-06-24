# frozen_string_literal: true

# Inner content of a single editable image-upload slide. The outer
# `<div class="item …">` wrapper (with its `data-form-images-target`,
# `data-form-exif-target`, `data-image-uuid`, `data-image-status`,
# `data-geocode` attributes) is owned by the `Components::Carousel`
# primitive (via `c.item(...) { render(this) }`); this component emits
# the image column + form column + control buttons that go inside.
#
# Layout:
# - Left column: image preview
# - Right column: form fields + camera info
# - Top-left overlay: set-as-thumbnail button
# - Top-right overlay: remove button (suppressed for sibling images)
#
# @example
#   render Components::Form::UploadGallery::Item.new(
#     user: @user,
#     image: @image,
#     upload: false,
#     obs_thumb_id: 123,
#     camera_info: { lat: "45.5", lng: "-122.6" }
#   )
class Components::Form::UploadGallery::Item < Components::Image::Base
  prop :upload, _Boolean, default: false
  prop :obs_thumb_id, _Nilable(::Integer), default: nil
  prop :camera_info, ::Hash, default: -> { {} }
  prop :sibling, _Boolean, default: false

  def initialize(upload: false, obs_thumb_id: nil, camera_info: {}, **props)
    props[:size] ||= :large
    props[:fit] ||= :contain
    extra_classes = "carousel-image"
    extra_classes += " set-src" if upload
    props[:extra_classes] ||= extra_classes
    super
  end

  def view_template
    @img_instance, @img_id = extract_image_and_id
    @img_id ||= "img_id_missing" if @upload
    @img_id = @img_id.id if @img_id.is_a?(::Image)
    @data = build_render_data(@img_instance, @img_id)

    div(class: "row") do
      render_image_column
      render_form_column unless @sibling
      render_control_buttons
    end
  end

  private

  def render_image_column
    div(class: "col-12 col-md-6") do
      div(class: "image-position") do
        img(
          src: @data[:img_src],
          alt: @notes,
          class: @data[:img_class],
          data: @data[:img_data]
        )
      end
    end
  end

  def render_form_column
    div(class: "col-12 col-md-6") do
      div(class: "form-panel") do
        render(Components::Form::UploadGallery::Fields.new(
                 user: @user,
                 image: @img_instance,
                 img_id: @img_id,
                 upload: @upload
               ))

        render(Components::Form::CameraInfo.new(
                 img_id: @img_id,
                 **@camera_info
               ))
      end
    end
  end

  def render_control_buttons
    render_thumbnail_button
    render_remove_button unless @sibling
  end

  def render_thumbnail_button
    div(class: "top-left p-4") { button_to_set_thumb_img }
  end

  # Real `observation[thumb_image_id]` radio — browser-native radio
  # group across carousel items submits the checked value directly,
  # no Stimulus round-trip via a separate hidden field. A static
  # hidden default with the same name (see
  # `ObservationFormUpload#render_thumb_image_id_field`) ensures the
  # param is always submitted (so removing the current thumb image
  # without picking another one clears the model field).
  #
  # The visual "pressed" state on the selected button is CSS-only
  # (`.thumb_img_btn:has(input[type="radio"]:checked)` in
  # `_carousel.scss`) — no JS to toggle `.active`.
  def button_to_set_thumb_img
    value = @img_instance&.id || "true"
    checked = @obs_thumb_id&.== @img_instance&.id

    render(Components::ApplicationForm::ButtonStyleRadio.new(
             name: "observation[thumb_image_id]",
             value: value,
             id: "thumb_image_id_#{@img_id}",
             checked: checked,
             size: :sm,
             label: { class: "thumb_img_btn" },
             class: "mr-3"
           )) do
      span(class: "set_thumb_img_text") { :image_set_default.l }
      span(class: "is_thumb_img_text") { :image_add_default.l }
    end
  end

  def render_remove_button
    div(class: "top-right p-4") do
      remove_image_button(@img_instance&.id)
    end
  end

  def remove_image_button(image_id)
    action = image_id ? "removeAttachedItem" : "removeClickedItem"
    data = { form_images_target: "removeImg",
             action: "form-images##{action}:prevent" }
    data[:image_id] = image_id if image_id

    render(Components::Button.new(
             size: :sm,
             class: "remove_image_button fade in",
             data: data
           )) do
      span { :image_remove_remove.l }
      render(Components::Icon.new(
               type: :remove, html_class: "text-danger ml-3"
             ))
    end
  end
end
