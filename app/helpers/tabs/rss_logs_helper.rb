# frozen_string_literal: true

# Custom View Helpers for Rss_log View (Activity Feed)
#
module Tabs
  module RssLogsHelper
    def rss_logs_index_tabs(user:, types:)
      [
        activity_log_default_types_for_user_tab(user, types)
      ]
    end

    def activity_log_default_types_for_user_tab(user, types)
      return unless params[:make_default] != "1"

      return unless user&.default_rss_type.to_s.split.sort != types

      [:rss_make_default.t,
       add_query_param(action: :index, make_default: 1),
       { class: tab_id(__method__.to_s) }]
    end
  end
end
