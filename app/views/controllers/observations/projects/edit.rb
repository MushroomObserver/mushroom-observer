# frozen_string_literal: true

# Action template for `Observations::ProjectsController#edit` — the
# "manage projects for this observation" page. Mirrors
# `Observations::SpeciesLists::Edit`, sharing
# `Components::ObservationListManager` for the two-section layout.
# Each section renders as a `Projects::ProjectTable`: projects the
# observation already belongs to (REMOVE button on each row) and the
# user's other projects (ADD button on each row).
module Views::Controllers::Observations::Projects
  class Edit < Views::FullPageBase
    prop :observation, ::Observation
    prop :all_projects, ::Query::Projects
    prop :obs_projects, _Array(::Project)
    prop :other_projects, _Array(::Project)

    def view_template
      add_page_title(
        :project_manage_title.t(
          name: viewer_aware_unique_format_name(@observation)
        ).small_author
      )
      add_sorter(@all_projects, ::ProjectsController.sort_options)
      add_context_nav(
        Tab::Observation::ListActions.new(observation: @observation)
      )
      add_pagination(nil)
      container_class(:wide)
      content_padding(:panels)

      PaginatedResults { render_manager }
    end

    private

    def render_manager
      ObservationListManager(
        belongs_to_heading: :project_manage_belongs_to.l,
        belongs_to_items: @obs_projects,
        not_contains_heading: :project_manage_doesnt_contain.l,
        not_contains_items: @other_projects
      ) do |projects, remove, add|
        render(Views::Controllers::Projects::ProjectTable.new(
                 projects, observation: @observation,
                           remove: remove, add: add
               ))
      end
    end
  end
end
