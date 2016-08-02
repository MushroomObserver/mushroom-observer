class Query::LocationWithDescriptionsInSet < Query::Location
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids:        [LocationDescription],
      old_title?: :string,
      old_by?:    :string
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("location_descriptions")
    add_join(:location_descriptions)
    super
  end
end
