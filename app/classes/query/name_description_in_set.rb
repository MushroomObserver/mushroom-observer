class Query::NameDescriptionInSet < Query::NameDescriptionBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [NameDescription]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("name_descriptions")
    super
  end
end
