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

  def carousel_set_thumb_image
    label_tag(
      "observation[thumb_image_id]",
      class: "btn btn-default btn-sm obs_thumb_img_btn",
      data: { obs_form_images_target: "obsThumbImgBtn",
              action: "click->obs-form-images#setObsThumbnail" }
    ) do
      [
        radio_button_tag(
          "observation[thumb_image_id]", "true",
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

  def carousel_exif_info
    tag.div(class: "form-group") do
      [
        tag.div do
          [tag.strong("Date: "), # :form_images_camera_date.t
           link_to("javascript:") { tag.span("", class: "exif_date") }].safe_join
        end,
        tag.div do
          [tag.strong("Lat: ") + tag.span("", class: "exif_lat"),
           tag.strong("Long: ") + tag.span("", class: "exif_lng"),
           tag.strong("Alt: ") + tag.span("", class: "exif_alt")].safe_join(", ")
        end,
        js_button(
          button: "Use this info",
          class: "use_exif_btn btn-sm ab-top-right",
          data: { action: "obs-form-images#transferExifToObs:prevent" }
        )
      ].safe_join
    end
  end
end
