# frozen_string_literal: true

# Projects section of the observation form.
# Renders a collapsible panel with project checkboxes and constraint messages.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param user [User] the current user
# @param button_name [String] submit button text for messages
# @param projects [Array<Project>] available projects
# @param project_checks [Hash] project_id => checked state
# @param error_checked_projects [Array<Project>] projects with constraint errors
# @param suspect_checked_projects [Array<Project>] projects with warnings
class Components::ObservationFormProjects < Components::Base
  prop :form, _Any
  prop :observation, Observation
  prop :user, User
  prop :button_name, String
  prop :projects, _Array(Project)
  prop :project_checks, Hash
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
      expanded: @project_checks.any?
    )
  end

  def render_body
    @form.namespace(:project) do |project_ns|
      render_constraint_messages(project_ns)
      render_help_text
      render_project_checkboxes(project_ns)
    end
  end

  def render_constraint_messages(project_ns)
    return unless constraint_issues?

    div(id: "project_messages") do
      render_error_alert if @error_checked_projects.any?
      render_warning_alert if @suspect_checked_projects.any?
    end
    render_ignore_checkbox(project_ns)
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
    render(Components::Alert.new(level: level)) do
      div do
        plain("#{:form_observations_projects_out_of_range.t(
          date: @observation.when,
          place_name: @observation.place_name
        )}:")
      end
      ul do
        projects.each do |proj|
          li { "#{proj.title} (#{proj.constraints})" }
        end
      end
      p { help_text }
    end
  end

  def render_ignore_checkbox(project_ns)
    render(project_ns.field(:ignore_proj_conflicts).checkbox(
             wrapper_options: {
               label: :form_observations_projects_ignore_project_constraints.t
             }
           ))
  end

  def render_help_text
    p { :form_observations_project_help.t }
  end

  def render_project_checkboxes(project_ns)
    div(class: "overflow-scroll-checklist") do
      @projects.each do |project|
        render_project_checkbox(project_ns, project)
      end
    end
  end

  def render_project_checkbox(project_ns, project)
    field_name = :"id_#{project.id}"
    checked = @project_checks[project.id]
    disabled = !project.user_can_add_observation?(@observation, @user)

    render(project_ns.field(field_name).checkbox(
             wrapper_options: { label: project.title },
             checked: checked,
             disabled: disabled
           ))
  end
end
