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
    pargs = params_out_to_with_descriptions_params
    Query.lookup(:Location, :with_descriptions, pargs)
  end
end
