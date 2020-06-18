# frozen_string_literal: true

class Query::LocationDescriptionInSet < Query::LocationDescriptionBase
  def parameter_declarations
    super.merge(
      ids: [Location::Description],
      old_by?: :string
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions_in_set, params_plus_old_by)
  end
end
