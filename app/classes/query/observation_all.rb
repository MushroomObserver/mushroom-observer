# frozen_string_literal: true

class Query::ObservationAll < Query::ObservationBase
  include Query::Initializers::ObservationQueryDescriptions

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations, params_plus_old_by)
  end

  def title
    default = super
    observation_query_description || default
  end
end
