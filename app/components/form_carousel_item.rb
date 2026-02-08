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
#   render Components::FormCarouselItem.new(
#     user: @user,
#     image: @image,
#     index: 0,
#     upload: false,
#     obs_thumb_id: 123,
#     camera_info: { lat: "45.5", lng: "-122.6", ... }
#   )
class Components::FormCarouselItem < Components::BaseImage
  # Additional form carousel-specific properties
  prop :index, Integer, default: 0
  prop :upload, _Boolean, default: false
  prop :obs_thumb_id, _Nilable(Integer), default: nil
  prop :camera_info, Hash, default: -> { {} }

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
        render_form_column
        render_control_buttons
      end
    end
  end

  def build_item_classes
    active = @index.zero? ? "active" : ""
    ["item carousel-item", active]
  end

  def build_item_data
    item_data = {
      form_images_target: "item",
      form_exif_target: "item",
      action: "form-exif:populated->form-images#itemExifPopulated",
      image_uuid: @img_id,
      image_status: @upload ? "upload" : "good"
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
        FormImageFields(
          user: @user,
          image: @img_instance,
          img_id: @img_id,
          upload: @upload
        )

        FormCameraInfo(
          img_id: @img_id,
          **@camera_info
        )
      end
    end
  end

  def render_control_buttons
    render_thumbnail_button
    render_remove_button
  end

  def render_thumbnail_button
    div(class: "top-left p-4") do
      button_to_set_thumb_img
    end
  end

  # Note that this is not `observation[thumb_image_id]`, a hidden field that
  # is set by the Stimulus controller on the basis of these radios' value.
  def button_to_set_thumb_img
    value = @img_instance&.id || "true"
    checked = @obs_thumb_id&.== @img_instance&.id
    label_classes = class_names("btn btn-default btn-sm thumb_img_btn",
                                active: checked)

    label(
      for: "thumb_image_id",
      class: label_classes,
      data: { form_images_target: "thumbImgBtn",
              action: "click->form-images#setObsThumbnail" }
    ) do
      input(type: :radio, name: "thumb_image_id",
            id: "thumb_image_id_#{value}", value: value,
            class: "mr-3", checked: checked,
            data: { form_images_target: "thumbImgRadio" })
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
      link_icon(:remove, class: "text-danger ml-3")
    end
  end
end
