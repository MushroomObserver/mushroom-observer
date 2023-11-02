# frozen_string_literal: true

module MatrixBoxHelper
  # Use this helper to produce a standard li.matrix-box with an object id.
  # Or, send your own column classes and other args
  def matrix_box(**args, &block)
    columns = args[:columns] || "col-xs-12 col-sm-6 col-md-4 col-lg-3"
    extra_classes = args[:class] || ""
    box_id = args[:id] ? "box_#{args[:id]}" : ""
    wrap_class = "matrix-box #{columns} #{extra_classes}"
    wrap_args = args.except(:columns, :class, :id)

    tag.li(class: wrap_class, id: box_id, **wrap_args) do
      capture(&block)
    end
  end

  def matrix_box_image(presenter, passed_args)
    return unless presenter.image_data

    image = presenter.image_data[:image]
    # for matrix_box_carousels: change to image_data.except(:images)
    image_args = passed_args.merge(presenter.image_data.except(:image) || {})

    tag.div(class: "thumbnail-container") do
      interactive_image(image, **image_args)
    end
  end

  # for matrix_box_carousels:
  # def matrix_box_images(presenter)
  #   presenter.image_data includes context: :matrix_box where appropriate
  #   images = presenter.image_data[:images]
  #   image_args = local_assigns.
  #                except(:columns, :object, :object_counter,
  #                       :object_iteration).
  #                merge(presenter.image_data.except(:images) || {})
  #   top_img = presenter.image_data[:thumb_image] || images.first
  #
  #   tag.div(class: "thumbnail-container") do
  #     carousel_html(object: object, images: images, top_img: top_img,
  #                   thumbnails: false, **image_args)
  #   end
  # end

  def matrix_box_details(presenter, object, object_id, identify)
    tag.div(class: "panel-body rss-box-details") do
      [
        matrix_box_what(presenter, object, object_id, identify),
        matrix_box_where(presenter),
        matrix_box_when_who(presenter)
      ].safe_join
    end
  end

  def matrix_box_what(presenter, object, object_id, identify)
    # bigger heading if no image
    h_element = presenter.image_data ? :h5 : :h3
    link_heading = tag.small("(#{presenter.id})", class: "rss-id float-right") +
                   tag.span(presenter.name, class: "rss-name",
                                            id: "box_title_#{object_id}")

    tag.div(class: "rss-what") do
      [
        content_tag(h_element, class: "mt-0 rss-heading") do
          link_with_query(link_heading, presenter.what.show_link_args)
        end,
        matrix_box_vote_or_propose_ui(identify, object)
      ].safe_join
    end
  end

  # Obs with uncertain name: vote on naming, or propose (if it's "Fungi")
  # used if matrix_box local_assigns identify == true
  def matrix_box_vote_or_propose_ui(identify, object)
    return unless identify

    if (object.name_id != 1) && (naming = object.consensus_naming)
      tag.div(class: "vote-select-container mb-3",
              data: { vote_cache: object.vote_cache }) do
        naming_vote_form(naming, nil, context: "matrix_box")
      end
    else
      propose_naming_link(object.id, btn_class: "btn-default mb-3",
                                     context: "matrix_box")
    end
  end

  def matrix_box_where(presenter)
    return unless presenter.place_name

    tag.div(class: "rss-where") do
      tag.small do
        location_link(presenter.place_name, presenter.where)
      end
    end
  end

  def matrix_box_when_who(presenter)
    return if presenter.when.blank?

    tag.div(class: "rss-what") do
      tag.small(class: "nowrap-ellipsis") do
        concat(tag.span(presenter.when, class: "rss-when"))
        concat(": ")
        concat(user_link(presenter.who, nil, class: "rss-who"))
      end
    end
  end

  def matrix_box_log_footer(presenter)
    return unless presenter.detail.present? || presenter.display_time.present?

    tag.div(class: "panel-footer log-footer") do
      if presenter.detail.present?
        concat(tag.div(presenter.detail, class: "rss-detail small"))
      end
      concat(tag.div(presenter.display_time, class: "rss-what small"))
    end
  end

  # Obs with uncertain name: mark as reviewed (to skip in future)
  # used if matrix_box local_assigns identify == true
  def matrix_box_identify_footer(identify, obs_id)
    return unless identify

    tag.div(class: "panel-footer panel-active text-center position-relative") do
      mark_as_reviewed_toggle(obs_id, "box_reviewed", "stretched-link")
    end
  end
end
