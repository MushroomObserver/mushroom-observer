# frozen_string_literal: true

class Query::Images < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Images
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  include Query::Titles::Observations

  def model
    Image
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      ids: [Image],
      by_user: User,
      users: [User],
      locations: [Location],
      outer: :query, # for images inside observations
      observation: Observation, # for images inside observations
      observations: [Observation],
      project: Project,
      projects: [Project],
      species_lists: [SpeciesList],
      with_observation: { boolean: [true] },
      # does not yet handle range of sizes. Param is minimum size.
      size: { string: Image::ALL_SIZES - [:full_size] },
      content_types: [{ string: Image::ALL_EXTENSIONS }],
      with_notes: :boolean,
      notes_has: :string,
      copyright_holder_has: :string,
      license: [License],
      with_votes: :boolean,
      quality: [:float],
      confidence: [:float],
      ok_for_export: :boolean,
      pattern: :string,
      with_observations: :boolean,
      observation_query: { subquery: :Observation }
    ).merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    super
    initialize_images_with_observations
    initialize_images_only_parameters
    add_pattern_condition
    add_img_advanced_search_conditions
    initialize_subquery_parameters
    initialize_img_record_parameters
    initialize_img_vote_parameters
  end

  def initialize_subquery_parameters
    add_subquery_condition(:observation_query,
                           { observation_images: :observations })
  end

  def initialize_images_with_observations
    return if params[:with_observations].blank?

    add_join(:observation_images, :observations)
  end

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
    return default if params[:with_observations].blank? &&
                      params[:observation_subquery].blank?

    with_observations_query_description || default
  end
end
