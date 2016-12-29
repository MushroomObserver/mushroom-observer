module Query
  # Locations with an rss log.
  class LocationByRssLog < Query::LocationBase
    def initialize_flavor
      add_join(:rss_logs)
      super
    end

    def default_order
      "rss_log"
    end
  end
end
