class Query::LocationWithDescriptions < Query::Location
  def parameter_declarations
    super
  end

  def initialize_flavor
    add_join(:"location_descriptions")
    super
  end
end
