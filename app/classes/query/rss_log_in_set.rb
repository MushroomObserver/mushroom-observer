module Query
  # Rss logs in a given set.
  class RssLogInSet < Query::RssLogBase
    def parameter_declarations
      super.merge(
        ids: [RssLog]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("rss_logs")
      super
    end
  end
end
