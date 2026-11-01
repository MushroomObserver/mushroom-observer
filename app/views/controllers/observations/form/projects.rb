# frozen_string_literal: true

# Projects section of the observation form. Collapsible panel with
# project checkboxes and constraint messages. Sub-component of
# `Views::Controllers::Observations::Form`.
#
# Wire shape: `observation[project_ids][]=<id>` (Rails-idiomatic
# has_many-through array). Checkedness defaults to
# `model.project_ids`; on a failure-reload the controller passes
# `submitted_project_ids:` (the user's just-submitted array) and the
# form uses that instead — preserves the user's choices without
# writing them to the DB (Rails' `*_ids=` setter is instant on a
# persisted record).
#
# `ignore_proj_conflicts` (the "ignore project warnings" checkbox)
# lives under `observation[ignore_proj_conflicts]`, not a `project[]`
# namespace.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param user [User] the current user
# @param button_name [String] submit button text for messages
# @param projects [Array<Project>] available projects
# @param submitted_project_ids [Array<Integer>, nil] user's just-
#   submitted project_ids (failure-reload path); nil on normal
#   render — form falls back to `observation.project_ids`.
# @param error_checked_projects [Array<Project>] projects with constraint errors
# @param suspect_checked_projects [Array<Project>] projects with warnings
class Views::Controllers::Observations::Form::Projects < Views::Base
  prop :form, ::Components::ApplicationForm
  prop :observation, Observation
  prop :user, User
  prop :button_name, String
  prop :projects, _Array(Project)
  prop :submitted_project_ids, _Nilable(_Array(Integer)),
       default: nil, &TO_ID_ARRAY
  prop :error_checked_projects, _Array(Project), default: -> { [] }
  prop :suspect_checked_projects, _Array(Project), default: -> { [] }
  prop :cross_prefix_projects, _Array(Project), default: -> { [] }
  prop :slip_target_project, _Nilable(Project), default: nil

  def view_template
    render(
      Components::Form::CheckboxPanel.new(
        form: @form,
        type: :project,
        form_object_name: "observation",
        objects: @projects,
        checked_ids: checked_project_ids,
        disabled_ids: disabled_project_ids,
        help_text: :form_observations_project_help.t,
        expanded: any_checked? || constraint_issues?
      )
    ) { render_constraint_messages }
  end

  private

  def checked_project_ids
    if @submitted_project_ids
      @submitted_project_ids.compact_blank
    else
      @observation.project_ids
    end
  end

  def disabled_project_ids
    @projects.reject do |project|
      project.user_can_change_membership?(@observation, @user)
    end.map(&:id)
  end

  def any_checked?
    checked_project_ids.any?
  end

  def render_constraint_messages
    return unless constraint_issues?

    div(id: "project_messages") do
      render_error_alert if @error_checked_projects.any?
      render_warning_alert if warning_projects.any?
    end
    render_ignore_checkbox
  end

  def constraint_issues?
    @error_checked_projects.any? || warning_projects.any?
  end

  def render_error_alert
    render_constraint_alert(:danger, @error_checked_projects,
                            :form_observations_projects_out_of_range_help.t)
  end

  # One alert, every problem project, each with its reasons -- a
  # constraint violation and a cross-prefix leftover read the same
  # way, so the user fixes everything in a single pass.
  def render_warning_alert
    help = :form_observations_projects_out_of_range_help.t
    help += :form_observations_projects_use_spare_help.t if spare_slip_option?
    help += :form_observations_projects_out_of_range_admin_help.t(
      button_name: @button_name
    )
    render_constraint_alert(:warning, warning_projects, help)
  end

  def spare_slip_option?
    @slip_target_project.present? || @cross_prefix_projects.any?
  end

  def warning_projects
    @suspect_checked_projects | @cross_prefix_projects
  end

  def render_constraint_alert(level, projects, help_text)
    Alert(level: level) do
      div { append_colon(:form_observations_projects_out_of_range.l) }
      ul do
        projects.each do |proj|
          li { "#{proj.title} (#{alert_reason_labels(proj)})" }
        end
      end
      p { help_text }
    end
  end

  # Joined, localized labels for everything wrong with `proj`: the
  # constraint kinds this observation violates (Non-target name;
  # Out-of-range date; etc.) plus the cross-prefix soft constraint.
  def alert_reason_labels(proj)
    kinds = proj.violation_kinds_for(@observation).map do |kind|
      :"form_observations_projects_kind_#{kind}".l
    end
    if @cross_prefix_projects.include?(proj)
      kinds << :form_observations_projects_kind_prefix_mismatch.l
    end
    kinds.join("; ")
  end

  def render_ignore_checkbox
    @form.checkbox_field(
      :ignore_proj_conflicts,
      label: :form_observations_projects_ignore_project_constraints
    )
    render_spare_slip_checkbox
  end

  # The opt-out for a slip used outside its event: attach it to this
  # observation with no project. Only offered when the slip's project
  # is part of the problem -- either violating (its target conflict)
  # or mismatched against a checked project's prefix.
  def render_spare_slip_checkbox
    return unless spare_slip_option?

    @form.checkbox_field(
      :use_spare_slip,
      label: :form_observations_projects_use_spare_slip
    )
  end
end
