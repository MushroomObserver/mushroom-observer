class Query::NameWithDescriptionsInSet < Query::Name
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Name],
      old_title?: :string,
      old_by?: :string
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("Name")
    super
  end

  def default_order
    super
  end
end
