# frozen_string_literal: true

module Views::Controllers::Images
  # Paginated images index — chrome + `Components::Grid` of
  # one image per row.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Image)
    prop :project, _Nilable(::Project), default: nil

    def view_template
      add_project_banner(@project) if @project
      container_class(:full)
      add_index_title(@query)
      add_context_nav(::Tab::Image::IndexActions.new(
                        query: @query, controller: controller
                      ))
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      PaginatedResults do
        Grid(
          objects: @objects, user: current_user
        )
      end
    end
  end
end
