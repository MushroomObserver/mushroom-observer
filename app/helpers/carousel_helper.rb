# frozen_string_literal: true

module CarouselHelper
  # Use this to print a carousel within a div
  # Required args: images:
  # Optional args: object: (the carousel is usually for an object)
  # top_img: (defaults to first), (carousel)title:, (image_edit)links:
  # thumbnails: true for thumbnail navigation
  # img_args: args for ImagePresenter
  #
  # Note: uses concat(x) instead of [x,y].safe_join because of conditionals
  def carousel_html(**args)
    args[:images] ||= nil
    args[:object] ||= nil
    args[:top_img] ||= args[:images].first
    args[:title] ||= :IMAGES.t
    args[:links] ||= ""
    args[:thumbnails] ||= true
    identifier = args[:object]&.type_tag || "image"
    args[:html_id] ||= "#{identifier}_carousel"

    if !args[:images].nil? && args[:images].any?
      concat(carousel_basic_html(**args))
    else
      if args[:thumbnails] # only need this heading on a show page
        concat(carousel_heading(args[:title], args[:links]))
      end
      concat(carousel_no_images_message)
    end
  end

  def carousel_basic_html(**args)
    tag.div(class: "carousel slide card-img", id: args[:html_id],
            data: { ride: "false", interval: "false" }) do
      concat(tag.div(class: "carousel-inner bg-light", role: "listbox") do
        args[:images].each do |image|
          concat(carousel_item(image, **args))
        end
        concat(carousel_controls(args[:html_id])) if args[:images].length > 1
      end)
      concat(carousel_heading(args[:title], args[:links]))
      concat(carousel_thumbnails(**args)) if args[:thumbnails]
    end
  end

  # args are leftover from template, could be used
  def carousel_item(image, **args)
    # Caption needs object for copyright info
    img_args = args.except(:images, :object, :top_img, :title, :links,
                           :thumbnails, :html_id)
    presenter_args = img_args.merge({ size: :large, fit: :contain,
                                      original: true,
                                      extra_classes: "carousel-image" })
    presenter = ImagePresenter.new(image, presenter_args)
    active = image == args[:top_img] ? "active" : ""

    tag.div(class: class_names("item", active)) do
      [
        image_tag(presenter.img_src, presenter.options_lazy),
        image_stretched_link(presenter.image_link, presenter.image_link_method),
        lightbox_link(presenter.lightbox_data),
        carousel_caption(image, args[:object], presenter)
      ].safe_join
    end
  end

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
      link_to("##{html_id}", class: "carousel-control-prev",
                             role: "button", data: { slide: "prev" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "fas fa-chevron-left fa-2x text-white",
                          aria: { hidden: "true" }))
          concat(tag.span(:PREV.l, class: "sr-only"))
        end
      end,
      link_to("##{html_id}", class: "carousel-control-next",
                             role: "button", data: { slide: "next" }) do
        tag.div(class: "btn") do
          concat(tag.span(class: "fas fa-chevron-right fa-2x text-white",
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

  def carousel_thumbnails(**args)
    tag.ol(class: "carousel-indicators bg-light mt-2 mb-0") do
      args[:images].each_with_index do |image, index|
        active = image == args[:top_img] ? "active" : ""

        concat(tag.li(class: class_names("carousel-indicator mx-1", active),
                      data: { target: "##{args[:html_id]}",
                              slide_to: index.to_s }) do
                 carousel_thumbnail(image)
               end)
      end
    end
  end

  def carousel_thumbnail(image)
    presenter_args = { fit: :contain, extra_classes: "carousel-thumbnail" }
    presenter = ImagePresenter.new(image, presenter_args)

    image_tag(presenter.img_src, presenter.options_lazy)
  end

  def carousel_no_images_message
    tag.div(:show_observation_no_images.l,
            class: class_names(%w[d-flex flex-column justify-content-center
                                  w-100 h-100 text-center h3 text-muted]))
  end
end
