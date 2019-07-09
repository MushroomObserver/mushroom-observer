# frozen_string_literal: true

module Query
  # intializing, parameter validation for Query's which return Comments
  class CommentBase < Query::Base
    def model
      Comment
    end

    def parameter_declarations
      super.merge(
        created_at?:  [:time],
        updated_at?:  [:time],
        users?:       [User],
        types?:       [{ string: Comment.all_type_tags }],
        summary_has?: :string,
        content_has?: :string
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("comments")
      add_string_enum_condition("comments.target_type", params[:types],
                                Comment.all_type_tags)
      add_search_condition("comments.summary", params[:summary_has])
      add_search_condition("comments.comment", params[:content_has])
      super
    end

    def default_order
      "created_at"
    end
  end
end
