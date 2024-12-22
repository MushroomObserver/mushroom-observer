# frozen_string_literal: true

class Query::NameWithDescriptions < Query::NameBase
  def parameter_declarations
    super.merge(descriptions_coercion_parameter_declarations)
  end

  def initialize_flavor
    add_join(:name_descriptions)
    initialize_with_desc_basic_parameters
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :all, params_back_to_description_params)
  end
end
