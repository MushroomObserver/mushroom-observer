# frozen_string_literal: true

class Query::Observations < Query::Base
  include Query::Initializers::Names
  include Query::Initializers::Observations
  include Query::Initializers::Locations
  include Query::Initializers::ContentFilters
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::ObservationsQueryDescriptions

  def model
    Observation
  end

  def parameter_declarations
    super.merge(observations_only_parameter_declarations).
      merge(observations_parameter_declarations).
      merge(bounding_box_parameter_declarations).
      merge(content_filter_parameter_declarations(Observation)).
      merge(names_parameter_declarations).
      merge(naming_consensus_parameter_declarations).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_obs_basic_parameters
    add_pattern_condition
    add_advanced_search_conditions
    add_needs_naming_condition
    initialize_name_parameters
    initialize_association_parameters
    initialize_obs_record_parameters
    initialize_obs_search_parameters
    initialize_confidence_parameter
    add_bounding_box_conditions_for_observations
    initialize_content_filters(Observation)
    super
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:names)
    super
  end

  def add_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    initialize_advanced_search
  end

  def initialize_association_parameters
    add_where_condition("observations", params[:locations])
    add_at_location_condition
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    add_for_project_condition(:project_observations)
    initialize_projects_parameter(:project_observations)
    initialize_project_lists_parameter
    add_in_species_list_condition
    initialize_species_lists_parameter
    initialize_field_slips_parameter
  end

  def add_join_to_names
    add_join(:names)
  end

  def add_join_to_users
    add_join(:users)
  end

  def add_join_to_locations
    add_join(:locations!)
  end

  def content_join_spec
    :comments
  end

  def search_fields
    "CONCAT(" \
      "names.search_name," \
      "observations.where" \
      ")"
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
    is_search = params[:pattern].present? ||
                advanced_search_params.any? { |key| params[key].present? }
    pargs = is_search ? add_old_title(params_plus_old_by) : params_plus_old_by
    # transform :ids to :obs_ids
    pargs = params_out_to_with_observations_params(pargs)
    Query.lookup(new_model, :all, pargs)
  end

  def title
    default = super
    observation_query_description || default
  end

  def self.default_order
    "date"
  end
end
