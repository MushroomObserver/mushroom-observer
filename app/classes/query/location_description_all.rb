class Query::LocationDescriptionAll < Query::LocationDescriptionBase
  include Query::Initializers::All

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions, params)
  end
end
