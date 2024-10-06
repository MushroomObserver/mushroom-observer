# frozen_string_literal: true

module Query
  # intializing, parameter validation for Query's which return Comments
  class CommentBase < Query::Base
    def model
      Comment
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        ids?: [Comment],
        by_user?: User,
        for_user?: User,
        users?: [User],
        types?: [{ string: Comment.all_type_tags }],
        summary_has?: :string,
        content_has?: :string,
        pattern?: :string,
        target?: AbstractModel,
        type?: :string
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("comments")
      add_by_user_condition("comments")
      initialize_ids_parameter
      add_for_user_condition
      add_for_target_condition
      add_pattern_parameter
      add_string_enum_condition("comments.target_type", params[:types],
                                Comment.all_type_tags)
      add_search_condition("comments.summary", params[:summary_has])
      add_search_condition("comments.comment", params[:content_has])
      super
    end

    def add_for_user_condition
      return if params[:for_user].blank?

      user = find_cached_parameter_instance(User, :for_user)
      @title_tag = :query_title_for_user
      @title_args[:user] = user.legal_name
      add_join(:observations)
      where << "observations.user_id = '#{params[:for_user]}'"
    end

    def add_for_target_condition
      return if params[:target].blank? || params[:type].blank?

      target = target_instance
      @title_tag = :query_title_for_target
      @title_args[:object] = target.unique_format_name
      where << "comments.target_id = '#{target.id}'"
      where << "comments.target_type = '#{target.class.name}'"
    end

    def target_instance
      unless (type = Comment.safe_model_from_name(params[:type]))
        raise("The model #{params[:type].inspect} does not support comments!")
      end

      find_cached_parameter_instance(type, :target)
    end

    def add_pattern_parameter
      return if params[:pattern].blank?

      @title_tag = :query_title_pattern_search
      add_search_condition(search_fields, params[:pattern])
    end

    def search_fields
      "CONCAT(" \
        "comments.summary," \
        "COALESCE(comments.comment,'')" \
        ")"
    end

    def self.default_order
      "created_at"
    end
  end
end
