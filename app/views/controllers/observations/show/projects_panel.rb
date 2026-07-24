# frozen_string_literal: true

# "Projects" panel on the observation show page. Read-only list of the
# projects this observation belongs to. Unlike `SpeciesListsPanel`,
# there's no add/remove-membership affordance here -- observations
# aren't added to or removed from a project from this page -- so the
# panel simply hides when the observation belongs to no projects.
class Views::Controllers::Observations::Show::ProjectsPanel < Views::Base
  prop :obs, ::Observation

  def view_template
    return if @obs.projects.empty?

    Panel(panel_id: "observation_projects") do |panel|
      panel.with_heading { plain(:projects.ti) }
      panel.with_body { render_list }
    end
  end

  private

  def render_list
    ul(class: "list-unstyled mb-0") do
      @obs.projects.each { |project| render_item(project) }
    end
  end

  def render_item(project)
    li { Link(type: :object, object: project) }
  end
end
