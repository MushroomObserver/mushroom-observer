# frozen_string_literal: true

# base class for Query's which return Names
class Query::Names < Query::Base
  include Query::Params::Names
  # include Query::Params::Descriptions
  # include Query::Params::Locations
  # include Query::Params::Observations
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Names
  # include Query::Initializers::Descriptions
  # include Query::Initializers::Locations
  # include Query::Initializers::Observations
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  include Query::Titles::Observations

  def model
    Name
  end

  def parameter_declarations
    super.merge(names_per_se_parameter_declarations).
      merge(content_filter_parameter_declarations(Name)).
      merge(names_parameter_declarations).
      # merge(name_descriptions_parameter_declarations). # no. send subquery
      merge(advanced_search_parameter_declarations)
    # q_p = super.merge(names_general_parameter_declarations)
    # if params[:with_descriptions].present?
    #   q_p.merge(names_with_descriptions_parameter_declarations)
    # elsif params[:with_observations].present?
    #   q_p.merge(names_with_observations_parameter_declarations)
    # else
    #   q_p
    # end
  end

  # def names_general_parameter_declarations
  #   names_per_se_parameter_declarations.
  #     merge(content_filter_parameter_declarations(Name)).
  #     merge(names_parameter_declarations).
  #     merge(name_descriptions_parameter_declarations). # yes in the general
  #     merge(advanced_search_parameter_declarations)
  # end

  # def names_with_descriptions_parameter_declarations
  #   descriptions_coercion_parameter_declarations
  # end

  # def names_with_observations_parameter_declarations
  #   observations_parameter_declarations.
  #     merge(observations_coercion_parameter_declarations).
  #     merge(bounding_box_parameter_declarations).
  #     merge(content_filter_parameter_declarations(Observation)).
  #     merge(naming_consensus_parameter_declarations)
  # end

  def initialize_flavor
    add_sort_order_to_title
    # if params[:with_descriptions].present?
    initialize_names_with_descriptions
    # elsif params[:with_observations].present?
    initialize_names_with_observations
    # else
    initialize_names_only_parameters
    # end
    initialize_taxonomy_parameters
    initialize_name_record_parameters
    initialize_name_search_parameters
    # initialize_name_descriptions_parameters
    initialize_content_filters(Name)
    super
  end

  def initialize_names_only_parameters
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_by_editor_condition
    initialize_name_comments_and_notes_parameters
    initialize_name_parameters_for_name_queries
    add_pattern_condition
    add_need_description_condition
    add_name_advanced_search_conditions
    initialize_subquery_parameters
    initialize_name_association_parameters
  end

  def initialize_subquery_parameters
    add_subquery_condition(:NameDescription, :name_descriptions)
    add_subquery_condition(:Observation, :observations)
    add_subquery_condition(:RssLog, :rss_logs)
    # add_subquery_condition(:Sequence, observations: :sequences)
  end

  def initialize_names_with_descriptions
    return if params[:with_descriptions].blank?

    add_join(:name_descriptions)
  #   initialize_with_desc_basic_parameters
  end

  def initialize_names_with_observations
    return if params[:with_observations].blank?

    add_join(:observations)
  #   initialize_obs_basic_parameters
  #   initialize_obs_association_parameters
  #   initialize_obs_record_parameters
  #   initialize_obs_search_parameters
  #   initialize_name_parameters(:observations)
  #   add_bounding_box_conditions_for_observations
  #   initialize_content_filters(Observation)
  end

  # def initialize_obs_association_parameters
  #   add_at_location_condition(:observations)
  #   project_joins = [:observations, :project_observations]
  #   initialize_projects_parameter(:project_observations, project_joins)
  #   add_for_project_condition(:project_observations, project_joins)
  #   add_in_species_list_condition
  #   initialize_herbaria_parameter
  # end

  def add_need_description_condition
    return unless params[:need_description]

    add_join(:observations)
    @where << "#{model.table_name}.description_id IS NULL"
    @title_tag = :query_title_needs_description.t(type: :name)
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:"name_descriptions.default!")
    super
  end

  def add_join_to_names; end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations
    add_join(:observations, :locations!)
  end

  def content_join_spec
    { observations: :comments }
  end

  def search_fields
    fields = [
      "names.search_name",
      "COALESCE(names.citation,'')",
      "COALESCE(names.notes,'')"
    ] + NameDescription.all_note_fields.map do |x|
      "COALESCE(name_descriptions.#{x},'')"
    end
    "CONCAT(#{fields.join(",")})"
  end

  def self.default_order
    "name"
  end

  # def coerce_into_name_description_query
  #   Query.lookup(:NameDescription, params_back_to_description_params)
  # end

  def title
    default = super
    if params[:with_observations]
      with_observations_query_description || default
    elsif params[:with_descriptions]
      :query_title_with_descriptions.t(type: :name) || default
    else
      default
    end
  end
end
