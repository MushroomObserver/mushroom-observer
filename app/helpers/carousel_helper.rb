# frozen_string_literal: true

module CarouselHelper
  # Very similar to an interactive_image caption
  def carousel_caption(user, image, object, presenter)
    classes = "carousel-caption"
    caption = if (info = image_info(image, object,
                                    original: presenter.original)).present?
                tag.div(info, class: "image-info d-none d-sm-block")
              else
                ""
              end

    tag.div(class: classes) do
      [
        image_vote_section_html(user, presenter.image, presenter.votes),
        caption
      ].safe_join
    end
  end

  def carousel_controls(html_id)
    [
      link_to("##{html_id}", class: "left carousel-control",
                             role: "button", data: { slide: "prev" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "glyphicon glyphicon-chevron-left",
                          aria: { hidden: "true" }))
          concat(tag.span(:PREV.l, class: "sr-only"))
        end
      end,
      link_to("##{html_id}", class: "right carousel-control",
                             role: "button", data: { slide: "next" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "glyphicon glyphicon-chevron-right",
                          aria: { hidden: "true" }))
          concat(tag.span(:NEXT.l, class: "sr-only"))
        end
      end
    ].safe_join
  end

  def carousel_heading(title, links = "")
    tag.div(class: "panel-heading carousel-heading") do
      tag.h4(class: "panel-title") do
        concat(title)
        concat(tag.span(links, class: "float-right"))
      end
    end
  end

  def carousel_no_images_message
    tag.div(:show_observation_no_images.l,
            class: "p-4 my-5 w-100 h-100 text-center h3 text-muted")
  end

  # What's generated by the presenter if there is an image record
  def carousel_item_img_classes
    "carousel-image img-fluid ab-fab object-fit-contain lazy"
  end

  def carousel_thumbnail_img_classes
    "carousel-thumbnail img-fluid ab-fab object-fit-contain lazy"
  end

  # For uploads, this should simply set a "true" value for the radio button.
  # For existing images, it should set the image id, and the `active` class.
  # Note that this is not `observation[thumb_image_id]`, a hidden field that
  # is set by the Stimulus controller on the basis of these radios' value.
  def carousel_set_thumb_img_button(image: nil, thumb_id: nil)
    value = image&.id || "true"
    checked = thumb_id&.== image&.id
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
        tag.span(:image_set_default.l, class: "set_thumb_img_text"),
        tag.span(:image_add_default.l, class: "is_thumb_img_text")
      ].safe_join
    end
  end

  def carousel_remove_image_button(image_id: nil)
    action = image_id ? "removeAttachedItem" : "removeClickedItem"
    data = { form_images_target: "removeImg",
             action: "form-images##{action}:prevent" }
    data[:image_id] = image_id if image_id

    js_button(
      name: "remove_image_button",
      class: "remove_image_button btn-sm fade in",
      data: data
    ) do
      [tag.span(:image_remove_remove.l),
       link_icon(:remove, class: "text-danger ml-3")].safe_join
    end
  end

  # Replaced by js
  def carousel_upload_messages
    tag.div(class: "carousel-upload-messages") do
      [
        tag.span("", class: "text-danger warn-text"),
        tag.span("", class: "text-success info-text")
      ].safe_join
    end
  end

  def carousel_exif_to_image_date_button(date: nil)
    link_to(
      "#",
      data: { action: "form-exif#exifToImageDate:prevent" }
    ) do
      tag.span(date, class: "exif_date")
    end
  end

  def carousel_transfer_exif_button(has_exif: false)
    js_button(
      name: "use_exif_button",
      class: class_names("use_exif_btn btn-sm ab-top-right",
                         "d-none": !has_exif),
      data: { form_exif_target: "useExifBtn",
              action: "form-exif#transferExifToObs:prevent" }
    ) do
      [tag.span(:image_use_exif.l, class: "when-enabled"),
       tag.span(:image_exif_copied.l, class: "when-disabled")].safe_join
    end
  end
end
