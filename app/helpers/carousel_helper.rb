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
end
