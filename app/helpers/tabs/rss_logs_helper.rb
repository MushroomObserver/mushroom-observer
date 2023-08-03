# frozen_string_literal: true

# Custom View Helpers for Rss_log View (Activity Feed)
#
module Tabs
  module RssLogsHelper
    # TABSET
    def rss_logs_index_tabset(user, types)
      tabs = [
        default_rss_types_for_user_tab(user, types)
      ]
      { right: draw_tab_set(tabs) }
    end

    def default_rss_types_for_user_tab(user, types)
      return unless params[:make_default] != "1"

      return unless user&.default_rss_type.to_s.split.sort != types

      link_to(:rss_make_default.t,
              add_query_param(action: :index, make_default: 1),
              class: "default_rss_types_for_user_link")
    end

    # FULL WIDTH TAB SET
    # The "Everything" tab in Activity Feed full_width_tab_set
    def log_tab_for_everything(types)
      label = :rss_all.t
      link = activity_logs_path(params: { type: :all })
      help = { title: :rss_all_help.t, class: "filter-only" }
      types == ["all"] ? label : link_with_query(label, link, **help)
    end

    # A single tab in Activity Feed full_width_tab_set
    def log_tab_for_type(types, type)
      label = :"rss_one_#{type}".t
      link = activity_logs_path(params: { type: type })
      help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
      types == [type] ? label : link_with_query(label, link, **help)
    end
  end
end
