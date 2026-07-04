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
      add_context_nav(::Tab::RssLog::IndexActions.new(
                        user: current_user, types: @types,
                        make_default_param: params[:make_default],
                        make_default_path: add_q_param(
                          action: :index, make_default: 1
                        )
                      ))
      add_type_filters(@query, @types)
      add_pagination(@pagination_data)
      container_class(:full)
    end
  end
end
