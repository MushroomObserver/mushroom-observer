# frozen_string_literal: true

# "Projects" panel on the observation show page. Mirrors
# `SpeciesListsPanel`: when the observation already belongs to
# projects, the heading is the bare "Projects" title with an
# icon-only "manage projects" link flush right (for users who are a
# member of any project), and the body lists every project the
# observation is part of, with an inline `[REMOVE]` button for any
# project the user is a member of. When the observation belongs to no
# projects yet, the whole heading is an icon+text "Add to a Project"
# link -- shown only if the user is a member of a project; otherwise
# the panel doesn't render at all.
class Views::Controllers::Observations::Show::ProjectsPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  def view_template
    return unless render_panel?

    Panel(panel_id: "observation_projects") do |panel|
      if @obs.projects.any?
        panel.with_heading { plain(:projects.ti) }
        panel.with_heading_links { manage_link } if manage_link?
        panel.with_body { render_list }
      else
        panel.with_heading { add_to_project_link }
      end
    end
  end

  private

  def render_panel?
    @obs.projects.any? || manage_link?
  end

  def manage_link?
    @user&.projects_member&.any?
  end

  def manage_link
    Link(type: :get,
         tab: ::Tab::Observation::ManageProjects.new(
           observation: @obs, q_param: q_param
         ))
  end

  def add_to_project_link
    Link(type: :get,
         tab: ::Tab::Observation::AddToProject.new(
           observation: @obs, q_param: q_param
         ),
         label: true)
  end

  def render_list
    ul(class: "list-unstyled mb-0") do
      @obs.projects.each { |project| render_item(project) }
    end
  end

  def render_item(project)
    li do
      Link(type: :object, object: project)
      if project.member_by_query?(@user)
        whitespace
        render_remove_button(project)
      end
    end
  end

  def render_remove_button(project)
    remove_path = observation_project_path(
      id: @obs.id, project_id: project.id, commit: "remove"
    )
    Button(
      type: :put,
      variant: :strip,
      icon: :remove,
      icon_class: "text-danger",
      name: :remove.ti,
      target: remove_path,
      confirm: :are_you_sure.l
    )
  end
end
