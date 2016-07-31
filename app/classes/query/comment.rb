class Query::Comment < Query::Base
  def model
    Comment
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      types?: :string,
      summary_has?: :string,
      content_has?: :string
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_enum_set(:types, :target_type, Comment.all_types, :string)
    initialize_model_do_search(:summary_has, :summary)
    initialize_model_do_search(:content_has, :comment)
    params[:by] ||= "created_at"
    super
  end
end
