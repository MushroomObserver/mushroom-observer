# frozen_string_literal: true

class Query::ScopeClasses::Comments < Query::BaseAR
  def model
    Comment
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [Comment],
      by_users: [User],
      for_user: User,
      types: [{ string: Comment::ALL_TYPE_TAGS }],
      summary_has: :string,
      content_has: :string,
      pattern: :string,
      target: { id: AbstractModel, type: :string }
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    add_for_user_condition
    add_for_target_condition
    add_pattern_condition
    add_string_enum_condition(Comment[:target_type], params[:types],
                              Comment::ALL_TYPE_TAGS)
    add_simple_search_condition(:summary)
    add_search_condition(:comment)
    super
  end

  def add_for_user_condition
    return if params[:for_user].blank?

    user = find_cached_parameter_instance(User, :for_user)
    @title_tag = :query_title_for_user
    @title_args[:user] = user.legal_name
    # where << "observations.user_id = '#{params[:for_user]}'"
    add_association_condition(Observation[:user_id], params[:for_user])
    @scopes = @scopes.joins(:observation)
  end

  def add_for_target_condition
    return if params[:target].blank?

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
