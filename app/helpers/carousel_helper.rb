# frozen_string_literal: true

module CarouselHelper
  # Very similar to an interactive_image caption
  def carousel_caption(image, object, presenter)
    classes = "carousel-caption"
    caption = if (info = image_info(image, object,
                                    original: presenter.original)).present?
                tag.div(info, class: "image-info d-none d-sm-block")
              else
                ""
              end

    tag.div(class: classes) do
      [
        image_vote_section_html(presenter.image, presenter.votes),
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

  # For uploads, this should simply set a "true" value for the radio button.
  # For existing images, it should set the image id, and active class
  def carousel_set_thumb_img(image: nil, active: "")
    value = image ? image.id : "true"
    label_classes = class_names("btn btn-default btn-sm obs_thumb_img_btn",
                                active)
    fields_for(:observation) do |f|
      f.label(
        :thumb_image_id,
        class: label_classes,
        data: { obs_form_images_target: "obsThumbImgBtn",
                action: "click->obs-form-images#setObsThumbnail" }
      ) do
        [
          f.radio_button(
            :thumb_image_id, value,
            class: "mr-3",
            data: { obs_form_images_target: "thumbImgRadio" }
          ),
          tag.span(
            :image_set_default.l,
            class: "set_thumb_img_text",
            data: { obs_form_images_target: "setThumbImg" }
          ),
          tag.span(
            :image_add_default.l,
            class: "is_thumb_img_text",
            data: { obs_form_images_target: "isThumbImg" }
          )
        ].safe_join
      end
    end
  end

  def carousel_remove_image_button(image_id = nil)
    action = image_id ? "removeAttachedItem" : "removeClickedItem"
    data = { obs_form_images_target: "removeImg",
             action: "obs-form-images##{action}:prevent" }
    data[:image_id] = image_id if image_id

    js_button(
      class: "remove_image_link btn-sm fade in",
      data: data
    ) do
      [tag.span(:image_remove_remove.l),
       tag.span(
         "", class: "glyphicon glyphicon-remove-circle text-danger ml-3"
       )].safe_join
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

  def carousel_exif_to_image_date_button
    link_to(
      "#",
      data: { action: "obs-form-images#exifToImageDate:prevent" }
    ) do
      tag.span("", class: "exif_date")
    end
  end

  def carousel_transfer_exif_button
    js_button(
      button: "Use this info",
      class: "use_exif_btn btn-sm ab-top-right",
      data: { action: "obs-form-images#transferExifToObs:prevent" }
    )
  end
end
