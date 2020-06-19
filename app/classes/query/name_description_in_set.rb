# frozen_string_literal: true

class Query::NameDescriptionInSet < Query::NameDescriptionBase
  def parameter_declarations
    super.merge(
      ids: [Name::Description],
      old_by?: :string
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions_in_set, params_plus_old_by)
  end
end
