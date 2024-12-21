# frozen_string_literal: true

class Query::NameWithDescriptions < Query::NameBase
  def parameter_declarations
    super.merge(
      desc_ids?: [NameDescription]
    ).merge(descriptions_coercion_parameter_declarations)
  end

  def initialize_flavor
    add_join(:name_descriptions)
    add_desc_ids_condition(:name)
    add_desc_by_user_condition(:name)
    add_desc_by_author_condition(:name)
    add_desc_by_editor_condition(:name)
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :all, params_back_to_description_params)
  end
end
