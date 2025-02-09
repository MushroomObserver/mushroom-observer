# frozen_string_literal: true

class Query::Images < Query::Base
  include Query::Params::Images
  # include Query::Params::Names
  # include Query::Params::Locations
  # include Query::Params::Observations
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Images
  # include Query::Initializers::Names
  # include Query::Initializers::Locations
  # include Query::Initializers::Observations
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  # include Query::Titles::Observations

  def model
    Image
  end

  def parameter_declarations
    super.merge(images_per_se_parameter_declarations).
      # merge(names_parameter_declarations). # nope. send obs_query
      merge(advanced_search_parameter_declarations)
    # q_p = super.merge(images_general_parameter_declarations)
    # return q_p if params[:with_observations].blank?

    # q_p.merge(images_with_observations_parameter_declarations)
  end

  # def images_general_parameter_declarations
  #   images_per_se_parameter_declarations.
  #     merge(names_parameter_declarations).
  #     merge(advanced_search_parameter_declarations)
  # end

  # def images_with_observations_parameter_declarations
  #   observations_parameter_declarations.
  #     merge(observations_coercion_parameter_declarations).
  #     merge(bounding_box_parameter_declarations).
  #     merge(content_filter_parameter_declarations(Observation)).
  #     merge(naming_consensus_parameter_declarations)
  # end

  def initialize_flavor
    add_sort_order_to_title
    super
    # if params[:with_observations].present?
    #   initialize_images_with_observations
    # else
    initialize_images_only_parameters
    # end
    add_pattern_condition
    add_img_advanced_search_conditions
    initialize_subquery_parameters
    initialize_name_parameters(:observation_images, :observations)
    initialize_img_record_parameters
    initialize_img_vote_parameters
  end

  def initialize_subquery_parameters
    add_subquery_condition(:observations, { observation_images: :observations })
  end

  # def initialize_images_with_observations
  #   add_join(:observation_images, :observations)
  #   initialize_obs_basic_parameters
  #   initialize_obs_association_parameters
  #   initialize_obs_record_parameters
  #   initialize_obs_search_parameters
  #   add_bounding_box_conditions_for_observations
  #   initialize_content_filters(Observation)
  # end

  # def initialize_obs_association_parameters
  #   add_at_location_condition(:observations)
  #   initialize_herbaria_parameter
  #   initialize_projects_parameter(:project_observations)
  #   add_for_project_condition(:project_observations,
  #                             [:observations, :project_observations])
  #   add_in_species_list_condition
  # end

  def initialize_images_only_parameters
    add_ids_condition
    add_img_inside_observation_conditions
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_date_condition("images.when", params[:date])
    add_join(:observation_images) if params[:with_observation]
    initialize_img_notes_parameters
    initialize_img_association_parameters
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:observation_images, :observations)
    add_join(:observations, :locations!)
    add_join(:observations, :names)
    super
  end

  def search_fields
    "CONCAT(" \
      "names.search_name," \
      "COALESCE(images.original_name,'')," \
      "COALESCE(images.copyright_holder,'')," \
      "COALESCE(images.notes,'')," \
      "observations.where" \
      ")"
  end

  def add_join_to_names
    add_join(:observations, :names)
  end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations
    add_join(:observations, :locations!)
  end

  def self.default_order
    "created_at"
  end

  def title
    default = super
    return default if params[:with_observations].blank?

    with_observations_query_description || default
  end
end
