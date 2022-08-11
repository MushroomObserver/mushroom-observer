# frozen_string_literal: true

# Custom View Helpers for Rss_log View (Activity Feed)
#
module RssLogHelper
  # All types of RssLogs
  def types
    RssLog.all_types(&:to_s)
  end

  # The "Everything" tab in Activity Feed tabset
  def tab_for_everything
    label = :rss_all.t
    link = activity_logs_path(params: { type: :all })
    help = { title: :rss_all_help.t }
    @types == ["all"] ? label : link_with_query(label, link, help)
  end

  # A single tab in Activity Feed tabset
  def tab_for_type(type)
    label = :"rss_one_#{type}".t
    link = activity_logs_path(params: { type: type })
    help = { title: :rss_one_help.t(type: type.to_sym) }
    @types == [type] ? label : link_with_query(label, link, help)
  end
end
