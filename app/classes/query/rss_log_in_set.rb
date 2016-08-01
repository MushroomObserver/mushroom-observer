class Query::RssLogInSet < Query::RssLog
  include Query::Initializers::InSet

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
