# frozen_string_literal: true

class Query::LocationDescriptionAll < Query::LocationDescriptionBase
  def parameter_declarations
    super.merge(
      old_by?: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions, params_plus_old_by)
  end
end
