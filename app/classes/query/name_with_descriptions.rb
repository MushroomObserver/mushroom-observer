class Query::NameWithDescriptions < Query::Name
  def parameter_declarations
    super
  end

  def initialize_flavor
    add_join(:"name_descriptions")
    super
  end
end
