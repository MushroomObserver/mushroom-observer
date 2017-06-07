module Query
  # Articles with an rss log.
  class ArticleByRssLog < Query::ArticleBase
    def initialize_flavor
      add_join(:rss_logs)
      super
    end

    def default_order
      "rss_log"
    end
  end
end
