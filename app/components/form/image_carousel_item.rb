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
#   render Components::Form::ImageCarouselItem.new(
#     user: current_user,
#     image: @image,
#     index: 0,
#     upload: false,
#     thumb_id: 123,
#     camera_info: { lat: "45.5", lng: "-122.6", ... }
#   )
class Components::Form::ImageCarouselItem < Components::BaseImage
  include Phlex::Rails::Helpers::LabelTag
  include Phlex::Rails::Helpers::RadioButtonTag

  # Additional form carousel-specific properties
  prop :index, Integer, default: 0
  prop :upload, _Boolean, default: false
  prop :thumb_id, _Nilable(Integer), default: nil
  prop :camera_info, Hash, default: -> { {} }

  def initialize(index: 0, upload: false, thumb_id: nil, camera_info: {},
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
    img_instance, img_id = extract_image_and_id
    img_id ||= "img_id_missing" if @upload

    # Build render data
    render_data = build_render_data(img_instance, img_id)

    # Render the carousel item
    render_form_carousel_item(img_instance, img_id, render_data)
  end

  private

  def render_form_carousel_item(img_instance, img_id, data)
    div(
      id: "carousel_item_#{img_id}",
      class: build_item_classes,
      data: build_item_data(img_id)
    ) do
      div(class: "row") do
        render_image_column(data)
        render_form_column(img_instance, img_id)
        render_control_buttons(img_instance)
      end
    end
  end

  def build_item_classes
    active = @index.zero? ? "active" : ""
    ["item carousel-item", active]
  end

  def build_item_data(img_id)
    item_data = {
      form_images_target: "item",
      form_exif_target: "item",
      action: "form-exif:populated->form-images#itemExifPopulated",
      image_uuid: img_id,
      image_status: @upload ? "upload" : "good"
    }

    item_data[:geocode] = @camera_info.to_json unless @upload
    item_data
  end

  def render_image_column(data)
    div(class: "col-12 col-md-6") do
      div(class: "image-position") do
        img(
          src: data[:img_src],
          alt: @notes,
          class: data[:img_class],
          data: data[:img_data]
        )
      end
    end
  end

  def render_form_column(img_instance, img_id)
    div(class: "col-12 col-md-6") do
      div(class: "form-panel") do
        render(Components::Form::ImageFields.new(
                 user: @user,
                 image: img_instance,
                 img_id: img_id,
                 upload: @upload
               ))

        render(Components::Form::ImageCameraInfo.new(
                 img_id: img_id,
                 **@camera_info
               ))
      end
    end
  end

  def render_control_buttons(img_instance)
    render_thumbnail_button(img_instance)
    render_remove_button(img_instance)
  end

  def render_thumbnail_button(img_instance)
    div(class: "top-left p-4") do
      set_thumb_img_button(img_instance)
    end
  end

  # Note that this is not `observation[thumb_image_id]`, a hidden field that
  # is set by the Stimulus controller on the basis of these radios' value.
  def set_thumb_img_button(image)
    value = image&.id || "true"
    checked = @thumb_id&.== image&.id
    label_classes = class_names("btn btn-default btn-sm thumb_img_btn",
                                active: checked)

    label_tag(
      :thumb_image_id,
      class: label_classes,
      data: { form_images_target: "thumbImgBtn",
              action: "click->form-images#setObsThumbnail" }
    ) do
      [
        radio_button_tag(
          :thumb_image_id, value,
          class: "mr-3", checked: checked,
          data: { form_images_target: "thumbImgRadio" }
        ),
        span(class: "set_thumb_img_text") { :image_set_default.l },
        span(class: "is_thumb_img_text") { :image_add_default.l }
      ].safe_join
    end
  end

  def render_remove_button(img_instance)
    div(class: "top-right p-4") do
      remove_image_button(img_instance&.id)
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
