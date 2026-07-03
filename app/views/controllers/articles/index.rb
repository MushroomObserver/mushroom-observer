# frozen_string_literal: true

module Views::Controllers::Articles
  # Paginated articles index. Page chrome (title, sorter, context-nav,
  # pagination) + a `Components::ListGroup::Base` of one article-summary
  # row per result.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Article)

    def view_template
      container_class(:wide)
      add_index_title(@query)
      add_context_nav(::Tab::Article::IndexActions.new(user: current_user))
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      PaginatedResults { render_list }
    end

    private

    def render_list
      render(::Components::ListGroup::Base.new) do |list|
        @objects.each do |article|
          list.item { render(ArticleItem.new(article: article)) }
        end
      end
    end
  end
end
