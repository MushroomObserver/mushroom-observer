# frozen_string_literal: true

# Action view for the species_list index page. Sets the project
# banner when scoped to a project, page chrome (title, sort, pagination,
# container width), then renders a `SpeciesListTable`.
module Views::Controllers::SpeciesLists
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::SpeciesList)
    prop :project, _Nilable(::Project), default: nil
    prop :observation_counts, _Hash(Integer, Integer), default: -> { {} }

    def view_template
      add_project_banner(@project) if @project
      add_index_title(@query)
      # Sort table lives on the controller — single source of truth.
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:full)

      PaginatedResults { render_list }
    end

    private

    def render_list
      return unless @objects.any?

      render(SpeciesListTable.new(
               @objects, project: @project,
                         observation_counts: @observation_counts
             ))
    end
  end
end
