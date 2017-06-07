module Query
  # Code common to all Article queries.
  class ArticleBase < Query::Base
    def model
      Article
    end

    def parameter_declarations
      super.merge(
        created_at?:        [:time],
        updated_at?:        [:time],
        users?:             [User],
        title_has?:         :string,
        body_has?:          :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_search(:title_has, :title)
      initialize_model_do_search(:body_has, :body)
      super
    end

    def default_order
      "created_at"
    end
  end
end
