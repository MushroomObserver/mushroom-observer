# frozen_string_literal: true

class Query::CommentForTarget < Query::CommentBase
  def parameter_declarations
    super.merge(
      target: AbstractModel,
      type: :string
    )
  end

  def initialize_flavor
    target = target_instance
    title_args[:object] = target.unique_format_name
    where << "comments.target_id = '#{target.id}'"
    where << "comments.target_type = '#{target.class.name}'"
    super
  end

  def target_instance
    unless (type = Comment.safe_model_from_name(params[:type]))
      raise("The model #{params[:type].inspect} does not support comments!")
    end

    find_cached_parameter_instance(type, :target)
  end
end
