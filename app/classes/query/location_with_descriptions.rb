# frozen_string_literal: true

class Query::LocationWithDescriptions < Query::LocationBase
  include Query::Initializers::Descriptions

  def parameter_declarations
    super.merge(descriptions_coercion_parameter_declarations)
  end

  def initialize_flavor
    add_join(:location_descriptions)
    initialize_with_desc_basic_parameters
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :all, params_back_to_description_params)
  end
end
