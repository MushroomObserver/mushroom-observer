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

  # This is called by turbo_stream to update the matrix_box title for an obs
  # in the event that the title is changed by a "help_identify" naming.
  # It can't be called by the matrix_box template currently because the title
  # and its link comes from the presenter, so it has to be kept in sync.
  # The matrix boxes should get separate templates with a dispatcher, and then
  # this can be DRYd up.
  def matrix_box_obs_title(obs)
    link_to(
      obs.format_name.t.break_name.small_author, # from matrix_box_presenter
      observation_path(obs.id, q: get_query_param)
    )
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
