# frozen_string_literal: true

module Views::Controllers::RssLogs
  # Activity logs index — the front-page matrix of recent activity
  # across observations / names / locations / etc., filtered by
  # selected RssLog types.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :rss_logs, _Array(::RssLog)
    prop :pagination_data, ::PaginationData
    prop :types, _Array(::String), default: -> { [] }

    def view_template
      register_chrome

      PaginatedResults do
        render(::Components::Matrix::Table.new(
                 objects: @rss_logs, user: current_user, cached: true
               ))
      end
    end

    private

    def register_chrome
      add_index_title(@query)
      add_type_filters(@query, @types, user: current_user)
      add_pagination(@pagination_data)
      container_class(:full)
    end
  end
end
