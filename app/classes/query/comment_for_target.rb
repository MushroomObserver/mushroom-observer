class Query::CommentForTarget < Query::CommentBase
  def parameter_declarations
    super.merge(
      target: AbstractModel,
      type: :string
    )
  end

  def initialize_flavor
    type = params[:type].to_s.constantize
    if !type.reflect_on_association(:comments)
      fail "The model #{params[:type].inspect} does not support comments!"
    end
    target = find_cached_parameter_instance(type, :target)
    title_args[:object] = target.unique_format_name
    self.where << "comments.target_id = '#{target.id}'"
    self.where << "comments.target_type = '#{type.name}'"
    super
  end
end
