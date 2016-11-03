class Query::ProjectInSet < Query::ProjectBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Project]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("projects")
    super
  end
end
