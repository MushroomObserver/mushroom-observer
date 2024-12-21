# frozen_string_literal: true

class Query::LocationWithDescriptions < Query::LocationBase
  include Query::Initializers::Descriptions

  def parameter_declarations
    super.merge(
      desc_ids?: [LocationDescription]
    ).merge(descriptions_coercion_parameter_declarations)
  end

  def initialize_flavor
    add_join(:location_descriptions)
    add_desc_ids_condition(:location)
    add_desc_by_user_condition(:location)
    add_desc_by_author_condition(:location)
    add_desc_by_editor_condition(:location)
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :all, params_back_to_description_params)
  end
end
