class Query::ArticleBase < Query::Base
  def model
    Article
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?:      [User],
      title_has?:  :string,
      body_has?:   :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("articles")
    add_search_condition("articles.title", params[:title_has])
    add_search_condition("articles.body", params[:body_has])
    super
  end

  def default_order
    "created_at"
  end
end
