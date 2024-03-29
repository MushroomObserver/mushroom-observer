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
    args[:size] ||= :large
    args[:top_img] ||= args[:images].first
    args[:title] ||= :IMAGES.t
    args[:links] ||= ""
    args[:thumbnails] = true if args[:thumbnails].nil?
    type = args[:object]&.type_tag || "image"
    args[:html_id] ||= "#{type}_#{args[:object].id}_carousel"

    capture do
      if !args[:images].nil? && args[:images].any?
        concat(carousel_basic_html(**args))
      else
        if args[:thumbnails] # only need this heading on a show page
          concat(carousel_heading(args[:title], args[:links]))
        end
        concat(carousel_no_images_message)
      end
    end
  end

  def carousel_basic_html(**args)
    tag.div(class: "carousel slide", id: args[:html_id],
            data: { ride: "false", interval: "false" }) do
      concat(carousel_heading(args[:title], args[:links])) if args[:thumbnails]
      concat(tag.div(class: "carousel-inner bg-light", role: "listbox") do
        args[:images].each do |image|
          concat(carousel_item(image, **args))
        end
        concat(carousel_controls(args[:html_id])) if args[:images].length > 1
      end)
      concat(carousel_thumbnails(**args)) if args[:thumbnails]
    end
  end

  # args are leftover from template, could be used
  def carousel_item(image, **args)
    # Caption needs object for copyright info
    img_args = args.except(:images, :object, :top_img, :title, :links,
                           :thumbnails, :html_id)
    presenter_args = img_args.merge({ fit: :contain, original: true,
                                      extra_classes: "carousel-image" })
    presenter = ImagePresenter.new(image, presenter_args)
    active = image == args[:top_img] ? "active" : ""

    tag.div(class: class_names("item", active)) do
      concat(image_tag(presenter.img_src, presenter.options_lazy))
      if presenter.image_link
        concat(image_stretched_link(presenter.image_link,
                                    presenter.image_link_method))
      end
      concat(lightbox_link(presenter.lightbox_data))
      concat(carousel_caption(image, args[:object], presenter))
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

  def carousel_thumbnails(**args)
    tag.ol(class: "carousel-indicators panel-footer py-2 px-0 mb-0") do
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
            class: "p-4 w-100 h-100 text-center h3 text-muted")
  end
end
