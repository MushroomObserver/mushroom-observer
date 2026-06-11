# frozen_string_literal: true

# Action template for `FieldSlipsController#new` — page chrome plus
# the field-slip form, followed by the
# `Components::Occurrences::Projects::Form` modal when the
# controller computed unresolved project memberships
# (`@field_slip_project_gaps`) for the obs about to be attached.
#
# Replaces `app/views/controllers/field_slips/new.html.erb`.
module Views::Controllers::FieldSlips
  class New < Views::Base
    prop :field_slip, ::FieldSlip
    # URL-param passthrough — `params[:species_list]` carries the
    # SpeciesList's id (as a String) the new obs should also be
    # added to once created; `FieldSlips::Form` emits it as a
    # hidden field so it survives a re-render. `nil` means no list.
    # Naming follows the existing flat-filter convention (bare
    # association name as the URL key, value is the id), same as
    # `?project=…` on the field-slip index.
    prop :species_list, _Nilable(String)
    prop :recent_observations, _Array(::Observation)
    # `Occurrence#project_membership_gaps` returns a Hash of the
    # shape `{ primary_missing: [...], has_non_primary_gaps: bool }`
    # (or empty); see `app/models/occurrence/project_gaps.rb`.
    prop :field_slip_project_gaps, _Nilable(Hash)
    prop :field_slip_occurrence, _Nilable(::Occurrence)

    def view_template
      add_page_title("#{:field_slip_new.t}: #{@field_slip.code}")
      add_context_nav(Tab::FieldSlip::Index.new)
      container_class(:full)

      render(Form.new(
               @field_slip,
               species_list: @species_list,
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
