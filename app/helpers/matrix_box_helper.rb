# frozen_string_literal: true

module MatrixBoxHelper
  # Use this helper to produce a li.log-item with an object id.
  # Or, send your own column classes and other args *b4
  def matrix_box(**args, &block)
    columns = args[:columns] || "col"
    extra_classes = " " || ""
    box_id = args[:id] ? "box_#{args[:id]}" : ""
    wrap_class = "matrix-box #{columns + extra_classes}"
    wrap_args = args.except(:columns, :class, :id)

    tag.li(class: wrap_class, id: box_id, **wrap_args) do
      capture(&block)
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
      propose_naming_link(object.id,
                          btn_class: "btn-sm btn-outline-secondary mb-3",
                          context: "matrix_box")
    end
  end

  def matrix_box_log_footer(presenter)
    return unless presenter.detail.present? || presenter.display_time.present?

    tag.div(class: "card-footer log-footer") do
      if presenter.detail.present?
        concat(tag.div(presenter.detail, class: "log-entry card-text mb-1"))
      end
      concat(tag.div(presenter.display_time, class: "log-what card-text"))
    end
  end

  # Obs with uncertain name: mark as reviewed (to skip in future)
  # used if matrix_box local_assigns identify == true
  def matrix_box_identify_footer(identify, obs_id)
    return unless identify

    tag.div(class: "card-footer card-active position-relative") do
      mark_as_reviewed_toggle(obs_id, "box_reviewed", "stretched-link")
    end
  end
end
