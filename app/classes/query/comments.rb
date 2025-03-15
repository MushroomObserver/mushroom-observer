# frozen_string_literal: true

class Query::Comments < Query::Base
  def model
    Comment
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Comment],
      by_users: [User],
      for_user: User,
      target: { type: :string, id: AbstractModel },
      types: [{ string: Comment::ALL_TYPE_TAGS }],
      summary_has: :string,
      content_has: :string,
      pattern: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    add_for_user_condition
    add_for_target_condition
    add_pattern_condition
    add_string_enum_condition("comments.target_type", params[:types],
                              Comment::ALL_TYPE_TAGS)
    add_search_condition("comments.summary", params[:summary_has])
    add_search_condition("comments.comment", params[:content_has])
    super
  end

  def add_for_user_condition
    return if params[:for_user].blank?

    add_join(:observations)
    @where << "observations.user_id = '#{params[:for_user]}'"
  end

  def add_for_target_condition
    return if params[:target].blank?

    target = target_instance
    @where << "comments.target_id = '#{target.id}'"
    @where << "comments.target_type = '#{target.class.name}'"
  end

  def target_instance
    type_param = params.dig(:target, :type)
    unless (type = Comment.safe_model_from_name(type_param))
      raise("The model #{type_param.inspect} does not support comments!")
    end

    type.safe_find(params.dig(:target, :id))
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
