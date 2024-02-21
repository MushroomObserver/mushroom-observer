# frozen_string_literal: true

module MatrixBoxHelper
  # Wrapper for a "grid" of matrix_boxes
  def matrix_table(**args, &block)
    partial = args[:partial] || "shared/matrix_box"
    as = args[:as] || :object
    cached = args[:cached] || false
    objects = args[:objects] || []
    locals = args.except(:objects, :as, :partial, :cached)

    [
      tag.ul(
        class: "row list-unstyled mt-3",
        data: { controller: "matrix-table",
                action: "resize@window->matrix-table#rearrange" }
      ) do
        if block
          capture(&block)
        elsif cached && objects
          render_cached_matrix_boxes(objects, locals)
        else
          render(partial: partial, locals: locals,
                 collection: objects, as: as)
        end
      end,
      tag.div("", class: "clearfix")
    ].safe_join
  end

  # Temporarily disabled to fix Russian Doll issues.
  def render_cached_matrix_boxes(objects, locals)
    # matrix box has one version except langs.
    # css hides image vote ui when body.no-user
    objects.each do |object|
      # cache(object) do
      concat(render(partial: "shared/matrix_box",
                    locals: { object: object }.merge(locals)))
      # end
    end
  end

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

  def matrix_box_image(image = nil, **args)
    return unless image

    tag.div(class: "thumbnail-container") do
      interactive_image(image, **args)
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

  # NOTE: object_id may be "no_ID" for logs of deleted records
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
    # heading style: bigger if no image.
    # TODO: make box layouts specific to object type
    h_style = presenter.image_data ? "h5" : "h3"
    what = presenter.what
    consensus = presenter.consensus || nil
    identify_ui = matrix_box_vote_or_propose_ui(identify, object, consensus)

    tag.div(class: "rss-what") do
      [
        tag.h5(class: class_names(%w[mt-0 rss-heading], h_style)) do
          link_with_query(what.show_link_args) do
            [
              matrix_box_id_tag(id: presenter.id),
              matrix_box_title(name: presenter.name, id: object_id)
            ].safe_join
          end
        end,
        identify_ui
      ].safe_join
    end
  end

  def matrix_box_id_tag(id:)
    tag.small("(#{id})", class: "rss-id float-right")
  end

  # NOTE: This is what gets Turbo updates with the identify UI
  #       (does not require presenter, only obs)
  def matrix_box_title(name:, id:)
    tag.span(name, class: "rss-name", id: "box_title_#{id}")
  end

  # Obs with uncertain name: vote on naming, or propose (if it's "Fungi")
  # used if matrix_box local_assigns identify == true
  def matrix_box_vote_or_propose_ui(identify, object, consensus)
    return unless identify

    if (object.name_id != 1) && (naming = consensus.consensus_naming)
      tag.div(class: "vote-select-container mb-3",
              data: { vote_cache: object.vote_cache }) do
        naming_vote_form(naming, nil, context: "matrix_box")
      end
    else
      propose_naming_link(
        object.id, btn_class: "btn btn-default d-inline-block mb-3",
                   context: "matrix_box"
)
    end
  end

  def matrix_box_where(presenter)
    return unless presenter.where

    tag.div(class: "rss-where") do
      tag.small do
        location_link(presenter.where, presenter.location)
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
