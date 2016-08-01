class Query::NameByRssLog < Query::Name
  def initialize
    add_join(:rss_logs)
    super
  end

  def default_order
    "rss_log"
  end
end
