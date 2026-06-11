# frozen_string_literal: true

# Action template for `FieldSlipsController#edit` — page chrome plus
# the field-slip form, followed by the
# `Components::Occurrences::Projects::Form` modal when the
# controller computed unresolved project memberships
# (`@field_slip_project_gaps`) for the obs about to be linked.
#
# Replaces `app/views/controllers/field_slips/edit.html.erb`.
module Views::Controllers::FieldSlips
  class Edit < Views::Base
    prop :field_slip, ::FieldSlip
    prop :recent_observations, _Array(::Observation)
    # `Occurrence#project_membership_gaps` returns a Hash of the
    # shape `{ primary_missing: [...], has_non_primary_gaps: bool }`
    # (or empty); see `app/models/occurrence/project_gaps.rb`.
    prop :field_slip_project_gaps, _Nilable(Hash)
    prop :field_slip_occurrence, _Nilable(::Occurrence)

    def view_template
      add_page_title("#{:field_slip_editing.t}: #{@field_slip.code}")
      add_context_nav(
        Tab::FieldSlip::FormEdit.new(field_slip: @field_slip)
      )
      container_class(:full)

      render(Form.new(
               @field_slip,
               recent_observations: @recent_observations,
               user: current_user
             ))

      render_unresolved_projects_modal if @field_slip_project_gaps&.any?
    end

    private

    def render_unresolved_projects_modal
      render(Components::Modal.new(
               id: "modal_resolve_projects",
               title: :occurrence_resolve_projects_title.l,
               dialog_class: "modal-dialog modal-lg",
               auto_open: true,
               user: current_user
             )) do |m|
        m.with_form_content do
          render(Views::Controllers::Occurrences::Projects::Form.new(
                   gaps: @field_slip_project_gaps,
                   primary: @field_slip_occurrence.primary_observation,
                   occurrence: @field_slip_occurrence
                 ))
        end
      end
    end
  end
end
