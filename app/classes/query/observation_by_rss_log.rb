class Query::ObservationByRssLog < Query::Observation
  def initialize
    add_join(:rss_logs)
    params[:by] ||= "rss_log"
  end
end
