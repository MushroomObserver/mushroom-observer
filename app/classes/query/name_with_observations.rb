class Query::NameWithObservations < Query::Name
  def parameter_declarations
    super
  end

  def initialize_flavor
    add_join(:"observation_descriptions")
    super
  end

  def default_order
    "name"
  end
end
