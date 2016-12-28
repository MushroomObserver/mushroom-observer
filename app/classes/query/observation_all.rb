class Query::ObservationAll < Query::ObservationBase
  include Query::Initializers::All

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations, params)
  end
end
