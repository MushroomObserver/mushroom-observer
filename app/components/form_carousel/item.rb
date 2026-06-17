# frozen_string_literal: true

# Form carousel item component for a single image in the observation form.
#
# This component displays an image alongside form fields for editing metadata.
# It inherits from BaseImage to handle image presentation logic.
#
# Layout:
# - Left column: Image display
# - Right column: Form fields and camera info
# - Top-left overlay: Set as thumbnail button
# - Top-right overlay: Remove image button
#
# @example
#   render Components::FormCarousel::Item.new(
#     user: @user,
#     image: @image,
#     index: 0,
#     upload: false,
#     obs_thumb_id: 123,
#     camera_info: { lat: "45.5", lng: "-122.6", ... }
#   )
class Components::FormCarousel::Item < Components::Image::Base
  # Additional form carousel-specific properties
  prop :index, Integer, default: 0
  prop :upload, _Boolean, default: false
  prop :obs_thumb_id, _Nilable(Integer), default: nil
  prop :camera_info, _Hash(Symbol, _Any?), default: -> { {} }
  prop :sibling, _Boolean, default: false

  def initialize(index: 0, upload: false, obs_thumb_id: nil, camera_info: {},
                 **props)
    # Set form carousel-specific defaults
    props[:size] ||= :large
    props[:fit] ||= :contain

    # Add carousel-image class, plus set-src for uploads
    extra_classes = "carousel-image"
    extra_classes += " set-src" if upload
    props[:extra_classes] ||= extra_classes

    super
  end

  def view_template
    # Get image instance and ID
    @img_instance, @img_id = extract_image_and_id
    @img_id ||= "img_id_missing" if @upload

    # Ensure img_id is not an Image object (convert to string if needed)
    # This should not be necessary! Remove
    @img_id = @img_id.id if @img_id.is_a?(::Image)

    # Build render data
    @data = build_render_data(@img_instance, @img_id)

    # Render the carousel item
    render_form_carousel_item
  end

  private

  def render_form_carousel_item
    div(
      id: "carousel_item_#{@img_id}",
      class: build_item_classes,
      data: build_item_data
    ) do
      div(class: "row") do
        render_image_column
        render_form_column unless @sibling
        render_control_buttons
      end
    end
  end

  def build_item_classes
    active = @index.zero? ? "active" : ""
    ["item carousel-item", active]
  end

  def build_item_data
    status = if @sibling then "sibling"
             elsif @upload then "upload"
             else "good"
             end
    item_data = {
      form_images_target: "item",
      form_exif_target: "item",
      action: "form-exif:populated->form-images#itemExifPopulated",
      image_uuid: @img_id,
      image_status: status
    }

    item_data[:geocode] = @camera_info.to_json unless @upload
    item_data
  end

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
        render(Components::FormCarousel::Fields.new(
                 user: @user,
                 image: @img_instance,
                 img_id: @img_id,
                 upload: @upload
               ))

        FormCameraInfo(
          img_id: @img_id,
          **@camera_info
        )
      end
    end
  end

  def render_control_buttons
    render_thumbnail_button
    render_remove_button unless @sibling
  end

  def render_thumbnail_button
    div(class: "top-left p-4") do
      button_to_set_thumb_img
    end
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

    # `id:` uses `@img_id` (unique per carousel item: image id for
    # server-rendered, UUID for upload placeholders) rather than
    # `value` (which is the literal string "true" for all
    # placeholders). Unique ids matter for the label `for=`
    # association (clicking the second placeholder's label otherwise
    # activates the first's radio) and for Capybara test selectors.
    # `value:` stays as "true" / image id; the JS post-upload hook
    # (`form-images#updateObsImages`) updates both the radio's value
    # AND its id to the real image id once assigned.
    render(Components::ApplicationForm::ButtonStyleRadio.new(
             name: "observation[thumb_image_id]",
             value: value,
             id: "thumb_image_id_#{@img_id}",
             checked: checked,
             label: { class: "btn btn-default btn-sm thumb_img_btn" },
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

    button_classes = class_names("btn btn-default",
                                 "remove_image_button btn-sm fade in")

    button(type: "button", class: button_classes, data: data) do
      span { :image_remove_remove.l }
      render(Components::LinkIcon.new(
               type: :remove, html_class: "text-danger ml-3"
             ))
    end
  end
end
