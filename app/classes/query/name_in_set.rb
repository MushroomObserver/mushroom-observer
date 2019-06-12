class Query::NameInSet < Query::NameBase
  def parameter_declarations
    super.merge(
      ids: [Name]
    )
  end

  def initialize_flavor
    add_id_condition("names.id", params[:ids])
    super
  end
end
