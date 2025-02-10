# frozen_string_literal: true

class Query::Locations < Query::Base
  include Query::Params::Locations
  # include Query::Params::Descriptions
  # include Query::Params::Names
  # include Query::Params::Observations
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Locations
  # include Query::Initializers::Descriptions
  # include Query::Initializers::Names
  # include Query::Initializers::Observations
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  # include Query::Titles::Observations

  def model
    Location
  end

  def parameter_declarations
    super.merge(locations_per_se_parameter_declarations).
      # merge(bounding_box_parameter_declarations).
      merge(content_filter_parameter_declarations(Location)).
      merge(advanced_search_parameter_declarations)
    # q_p = super.merge(locations_general_parameter_declarations)
    # if params[:with_descriptions].present?
    #   q_p.merge(locations_with_descriptions_parameter_declarations)
    # elsif params[:with_observations].present?
    #   q_p.merge(locations_with_observations_parameter_declarations)
    # else
    #   q_p
    # end
  end

  # def locations_general_parameter_declarations
  #   locations_per_se_parameter_declarations.
  #     merge(bounding_box_parameter_declarations).
  #     merge(content_filter_parameter_declarations(Location)).
  #     merge(advanced_search_parameter_declarations)
  # end

  # def locations_with_descriptions_parameter_declarations
  #   descriptions_coercion_parameter_declarations
  # end

  # def locations_with_observations_parameter_declarations
  #   observations_parameter_declarations.
  #     merge(observations_coercion_parameter_declarations).
  #     merge(content_filter_parameter_declarations(Observation)).
  #     merge(names_parameter_declarations).
  #     merge(naming_consensus_parameter_declarations)
  # end

  def initialize_flavor
    add_sort_order_to_title
    # if params[:with_descriptions].present?
    #   initialize_locations_with_descriptions
    # elsif params[:with_observations].present?
    #   initialize_locations_with_observations
    # else
    initialize_locations_only_parameters
    # end
    add_bounding_box_conditions_for_locations
    initialize_subquery_parameters
    initialize_content_filters(Location)
    super
  end

  # def initialize_locations_with_descriptions
  #   add_join(:location_descriptions)
  #   initialize_with_desc_basic_parameters
  # end

  # def initialize_locations_with_observations
  #   add_join(:observations)
  #   initialize_obs_basic_parameters
  #   initialize_name_parameters
  #   initialize_obs_association_parameters
  #   initialize_obs_record_parameters
  #   initialize_obs_search_parameters
  #   initialize_content_filters(Observation)
  # end

  def initialize_locations_only_parameters
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_by_editor_condition
    initialize_location_notes_parameters
    add_pattern_condition
    add_regexp_condition
    add_advanced_search_conditions
  end

  def initialize_subquery_parameters
    add_subquery_condition(:descriptions, :location_descriptions)
    add_subquery_condition(:observations, :observations)
    add_subquery_condition(:rss_logs, :rss_logs)
  end

  # def initialize_obs_association_parameters
  #   add_at_location_condition(:observations)
  #   add_where_condition(:observations, params[:locations])
  #   project_joins = [:observations, :project_observations]
  #   add_for_project_condition(:project_observations, project_joins)
  #   initialize_projects_parameter(:project_observations, project_joins)
  #   add_in_species_list_condition
  #   initialize_species_lists_parameter
  #   initialize_herbaria_parameter
  # end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:"location_descriptions.default!")
    super
  end

  def add_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join(:observations) if params[:content].present?
    initialize_advanced_search
  end

  def add_join_to_names
    add_join(:observations, :names)
  end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations; end

  def content_join_spec
    { observations: :comments }
  end

  def search_fields
    "CONCAT(" \
      "locations.name," \
      "#{LocationDescription.all_note_fields.map do |x|
           "COALESCE(location_descriptions.#{x},'')"
         end.join(",")}" \
    ")"
  end

  def self.default_order
    "name"
  end

  # def coerce_into_location_description_query
  #   Query.lookup(:LocationDescription, params_back_to_description_params)
  # end

  def title
    default = super
    if params[:with_observations]
      with_observations_query_description || default
    elsif params[:with_descriptions]
      :query_title_with_descriptions.t(type: :location) || default
    else
      default
    end
  end
end
