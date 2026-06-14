# frozen_string_literal: true

module Views::Controllers::Contributors
  # Paginated contributors index. Page chrome (title, sorter,
  # context-nav, pagination) + a one-row collapsible Legend +
  # a MatrixTable of user matrix-boxes. Converted from
  # `contributors/index.html.erb` + `contributors/_legend.erb`.
  class Index < Views::Base
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
      paginated_results do
        render(::Components::MatrixTable.new(objects: @objects))
      end
    end

    private

    def render_legend_row
      div(class: "row my-3") do
        div(class: "col-md-8 col-lg-6") { render(Legend.new) }
      end
    end
  end
end
