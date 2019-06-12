class Query::RssLogInSet < Query::RssLogBase
  def parameter_declarations
    super.merge(
      ids: [RssLog]
    )
  end

  def initialize_flavor
    add_id_condition("rss_logs.id", params[:ids])
    super
  end
end
