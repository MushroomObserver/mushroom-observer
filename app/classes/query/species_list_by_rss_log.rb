class Query::SpeciesListByRssLog < Query::SpeciesList
  def initialize
    add_join(:rss_logs)
    super
  end

  def default_order
    "rss_log"
  end
end
