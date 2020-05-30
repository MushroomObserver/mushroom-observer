# Custom View Helpers for rss_log View (Activity Feed)
#
module RssLogsHelper
  # All types of RssLogs
  def types
    RssLog.all_types(&:to_s)
  end

  # The "Everything" tab in Activity Feed tabset
  def tab_for_everything
    label = :rss_all.t
    link = { action: :index_rss_log, type: :all }
    help = { title: :rss_all_help.t }
    @types == ["all"] ? label : link_with_query(label, link, help)
  end

  # A single tab in Activity Feed tabset
  def tab_for_type(type)
    label = :rss_one.t(type: type.classify.constantize.rss_log_tab_label)
    link = { action: :index_rss_log, type: type }
    help = { title: :rss_one_help.t(type: type.to_sym) }
    @types == [type] ? label : link_with_query(label, link, help)
  end
end
