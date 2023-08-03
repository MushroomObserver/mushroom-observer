# frozen_string_literal: true

# Custom View Helpers for Rss_log View (Activity Feed)
#
module Tabs
  module RssLogsHelper
    # TABSET @links already produced by controller

    # type filters full_width_tab_set in #index
    # The "Everything" tab
    def log_tab_for_everything(types)
      label = :rss_all.t
      link = activity_logs_path(params: { type: :all })
      help = { title: :rss_all_help.t, class: "filter-only" }
      types == ["all"] ? label : link_with_query(label, link, **help)
    end

    # A single tab
    def log_tab_for_type(types, type)
      label = :"rss_one_#{type}".t
      link = activity_logs_path(params: { type: type })
      help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
      types == [type] ? label : link_with_query(label, link, **help)
    end
  end
end
