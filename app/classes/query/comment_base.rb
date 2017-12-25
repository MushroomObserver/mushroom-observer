module Query
  # Common code for all comment queries.
  class CommentBase < Query::Base
    def model
      Comment
    end

    def parameter_declarations
      super.merge(
        created_at?:  [:time],
        updated_at?:  [:time],
        users?:       [User],
        types?:       [{string: Comment.all_type_tags}],
        summary_has?: :string,
        content_has?: :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_enum_set(:types, :target_type, Comment.all_type_tags,
                                   :string)
      initialize_model_do_search(:summary_has, :summary)
      initialize_model_do_search(:content_has, :comment)
      super
    end

    def default_order
      "created_at"
    end
  end
end
