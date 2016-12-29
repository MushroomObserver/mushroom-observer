class Query::NameDescriptionInSet < Query::NameDescriptionBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids:     [NameDescription],
      old_by?: :string
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("name_descriptions")
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions_in_set, params_plus_old_by)
  end
end
