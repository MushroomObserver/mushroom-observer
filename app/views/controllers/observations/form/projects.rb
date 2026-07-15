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
# now lives under `observation[ignore_proj_conflicts]` rather than
# its own `project[]` namespace.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param user [User] the current user
# @param button_name [String] submit button text for messages
# @param projects [Array<Project>] available projects
# @param submitted_project_ids [Array<String>, nil] user's just-
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
  prop :submitted_project_ids, _Nilable(_Array(String)), default: nil
  prop :error_checked_projects, _Array(Project), default: -> { [] }
  prop :suspect_checked_projects, _Array(Project), default: -> { [] }

  def view_template
    render(panel) do |p|
      p.with_heading { :PROJECTS.l }
      p.with_body(collapse: true) { render_body }
    end
  end

  private

  def panel
    Components::Panel.new(
      panel_id: "observation_projects",
      collapsible: true,
      collapse_target: "#observation_projects_inner",
      expanded: any_checked?
    )
  end

  def any_checked?
    if @submitted_project_ids
      @submitted_project_ids.compact_blank.any?
    else
      @observation.project_ids.any?
    end
  end

  def render_body
    render_constraint_messages
    render_help_text
    render_project_checkboxes
  end

  def render_constraint_messages
    return unless constraint_issues?

    div(id: "project_messages") do
      render_error_alert if @error_checked_projects.any?
      render_warning_alert if @suspect_checked_projects.any?
    end
    render_ignore_checkbox
  end

  def constraint_issues?
    @error_checked_projects.any? || @suspect_checked_projects.any?
  end

  def render_error_alert
    render_constraint_alert(:danger, @error_checked_projects,
                            :form_observations_projects_out_of_range_help.t)
  end

  def render_warning_alert
    help = :form_observations_projects_out_of_range_help.t +
           :form_observations_projects_out_of_range_admin_help.t(
             button_name: @button_name
           )
    render_constraint_alert(:warning, @suspect_checked_projects, help)
  end

  def render_constraint_alert(level, projects, help_text)
    Alert(level: level) do
      div { plain("#{:form_observations_projects_out_of_range.t}:") }
      ul do
        projects.each do |proj|
          li { "#{proj.title} (#{constraint_kind_labels(proj)})" }
        end
      end
      p { help_text }
    end
  end

  # Joined, localized kind labels for the violations this observation
  # incurs against `proj` (Non-target name; Out-of-range date; etc.).
  def constraint_kind_labels(proj)
    proj.violation_kinds_for(@observation).map do |kind|
      :"form_observations_projects_kind_#{kind}".l
    end.join("; ")
  end

  def render_ignore_checkbox
    @form.checkbox_field(
      :ignore_proj_conflicts,
      label: :form_observations_projects_ignore_project_constraints
    )
  end

  def render_help_text
    p { :form_observations_project_help.t }
  end

  def render_project_checkboxes
    div(class: "overflow-scroll-checklist") do
      # Sentinel: ensures `observation[project_ids]` is always present
      # in params even when every checkbox is unchecked (Rack drops
      # empty arrays). Controller `compact_blank`s this empty value.
      input(type: "hidden", name: "observation[project_ids][]",
            value: "", autocomplete: "off")
      @projects.each { |project| render_project_checkbox(project) }
    end
  end

  def render_project_checkbox(project)
    @form.checkbox_field(
      :project_ids,
      label: false,
      disabled: !project.user_can_add_observation?(@observation, @user)
    ) do |cb|
      cb.option(project.id, checked: project_checked?(project.id)) do
        whitespace
        plain(project.title)
      end
    end
  end

  def project_checked?(project_id)
    if @submitted_project_ids
      @submitted_project_ids.map(&:to_i).include?(project_id.to_i)
    else
      @observation.project_ids.include?(project_id)
    end
  end
end
