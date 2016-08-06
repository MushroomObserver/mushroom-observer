class Query::NameInSet < Query::NameBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Name]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("names")
    super
  end
end
