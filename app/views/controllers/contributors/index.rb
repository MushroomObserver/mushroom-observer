# frozen_string_literal: true

module Views::Controllers::Contributors
  # Paginated contributors index. Page chrome (title, sorter,
  # context-nav, pagination) + a one-row collapsible Legend +
  # a MatrixTable of user matrix-boxes.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::User)

    def view_template
      container_class(:double)
      add_page_title(:users_by_contribution_title.t)
      add_context_nav(::Tab::Contributor::IndexActions.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      render_legend_row
      PaginatedResults do
        render(::Components::Matrix::Table.new(objects: @objects))
      end
    end

    private

    def render_legend_row
      Row(class: "my-3") do
        Column(md: 8, lg: 6) { render(Legend.new) }
      end
    end
  end
end
