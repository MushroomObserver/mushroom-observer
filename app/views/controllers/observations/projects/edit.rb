# frozen_string_literal: true

# Action template for `Observations::ProjectsController#edit` — the
# "manage projects for this observation" page. Mirrors
# `Observations::SpeciesLists::Edit`. Renders two
# `Components::ListGroup`s of `Projects::ListItem` rows: projects the
# observation already belongs to (REMOVE button on each) and the
# user's other projects (ADD button on each).
module Views::Controllers::Observations::Projects
  class Edit < Views::FullPageBase
    prop :observation, ::Observation
    prop :obs_projects, _Array(::Project)
    prop :other_projects, _Array(::Project)

    def view_template
      add_page_title(
        :project_manage_title.t(
          name: viewer_aware_unique_format_name(@observation)
        )
      )
      add_context_nav(
        Tab::Observation::ListActions.new(observation: @observation)
      )
      container_class(:wide)
      content_padding(:panels)

      div(class: "p-3") { render_sections }
    end

    private

    def render_sections
      render_section(
        heading: :project_manage_belongs_to.l,
        projects: @obs_projects, remove: true
      )
      render_section(
        heading: :project_manage_doesnt_contain.l,
        projects: @other_projects, add: true
      )
    end

    # No-op when the source array is empty.
    def render_section(heading:, projects:, remove: false, add: false)
      return if projects.empty?

      h5(class: "mt-3") { trusted_html(append_colon(heading)) }
      ListGroup do |list|
        projects.each do |project|
          list.item(
            class: "d-flex justify-content-between align-items-start"
          ) do
            render_item(project: project, remove: remove, add: add)
          end
        end
      end
    end

    def render_item(project:, remove:, add:)
      render(
        Views::Controllers::Projects::ListItem.new(
          project: project,
          observation: @observation,
          remove: remove,
          add: add,
          violation_kinds: add ? project.violation_kinds_for(@observation) : []
        )
      )
    end
  end
end
