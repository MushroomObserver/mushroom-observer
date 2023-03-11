# frozen_string_literal: true

module MatrixBoxHelper
  # Obs with uncertain name: vote on naming, or propose (if it's "Fungi")
  # used if matrix_box local_assigns identify == true
  def vote_or_propose_ui(identify, object)
    return unless identify

    if (object.name_id != 1) && (nam = object.consensus_naming)
      content_tag(:div, class: "vote-select-container mb-3") do
        render(partial: "observations/namings/votes/form",
               locals: { naming: nam })
      end
    else
      propose_naming_link(object.id, "btn-default mb-3")
    end
  end

  # Obs with uncertain name: mark as reviewed (to skip in future)
  # used if matrix_box local_assigns identify == true
  def identify_footer(identify, object_id)
    return unless identify

    content_tag(
      :div,
      class: "panel-footer panel-active text-center position-relative"
    ) do
      mark_as_reviewed_toggle(object_id, "box_reviewed", "stretched-link")
    end
  end
end
