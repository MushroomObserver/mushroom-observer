class Query::ProjectInSet < Query::ProjectBase
  def parameter_declarations
    super.merge(
      ids: [Project]
    )
  end

  def initialize_flavor
    add_id_condition("projects.id", params[:ids])
    super
  end
end
