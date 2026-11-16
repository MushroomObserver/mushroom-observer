# frozen_string_literal: true

# Action template for the Projects index.
#
# `ProjectsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::Projects
  class Index < Views::FullPageBase
    prop :query, ::Query::Projects
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Project)
    prop :observation_counts, _Hash(Integer, Integer), default: -> { {} }

    def view_template
      add_index_title(@query)
      add_context_nav(Tab::Project::IndexNav.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:full)

      PaginatedResults { render_table }
    end

    private

    def render_table
      render(ProjectTable.new(@objects,
                              observation_counts: @observation_counts))
    end
  end
end
