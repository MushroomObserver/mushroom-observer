class Query::LocationInSet < Query::LocationBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Location]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("locations")
    super
  end
end
