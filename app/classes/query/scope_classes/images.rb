# frozen_string_literal: true

# base class for Queries which return Names
class Query::ScopeClasses::Images < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::ScopeInitializers::AdvancedSearch
  include Query::ScopeInitializers::Filters
  include Query::Titles::Observations

  def model
    Image
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      date: [:date],
      id_in_set: [Image],
      by_users: [User],
      size: [{ string: Image::ALL_SIZES - [:full_size] }],
      content_types: [{ string: Image::ALL_EXTENSIONS }],
      has_notes: :boolean,
      notes_has: :string,
      copyright_holder_has: :string,
      license: [License],
      has_votes: :boolean,
      quality: [:float],
      confidence: [:float],
      ok_for_export: :boolean,
      pattern: :string,
      locations: [Location],
      observations: [Observation],
      projects: [Project],
      species_lists: [SpeciesList],
      has_observations: :boolean,
      observation_query: { subquery: :Observation }
    ).merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_image_parameters
    initialize_image_association_parameters
    initialize_subquery_parameters
    add_pattern_condition
    add_img_advanced_search_conditions
    super
  end

  def initialize_image_parameters
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions
    intialize_date_condition
    initialize_has_notes_parameter
    initialize_notes_has_parameter
    add_search_condition("images.copyright_holder",
                         params[:copyright_holder_has])
    add_image_size_condition(params[:size])
    add_image_type_condition(params[:content_types])
    initialize_ok_for_export_parameter
  end

  def initialize_date_condition
    return unless params[:date]

    @scopes = @scopes.date(params[:date])
  end

  def initialize_has_notes_parameter
    return unless params[:has_notes]

    @scopes = @scopes.has_notes(params[:has_notes])
  end

  def initialize_notes_has_parameter
    return unless params[:notes_has]

    @scopes = @scopes.notes_has(params[:notes_has])
  end

  def initialize_img_association_parameters
    initialize_observations_parameter
    add_observation_location_condition(
      Observation, params[:locations], { observation_images: :observations }
    )
    add_for_project_condition(ProjectImage)
    initialize_projects_parameter(ProjectImage, :project_images)
    initialize_species_lists_parameter(
      SpeciesListObservation,
      { observation_images: { observations: :species_list_observations } }
    )
    add_association_condition(Image[:license_id], params[:license])
  end

  def initialize_img_record_parameters
    add_search_condition(
      Image[:copyright_holder], params[:copyright_holder_has]
    )
    add_image_size_conditions(params[:size])
    add_image_type_condition(params[:content_types])
    initialize_ok_for_export_parameter
  end

  def add_image_size_conditions(vals, joins)
    return if vals.empty?

    min, max = vals
    @scopes = @scopes.merge(Image.with_sizes(min, max))
    @scopes = @scopes.joins(**joins) if joins
  end

  def add_image_type_condition(vals, joins)
    return if vals.empty?

    @scopes = @scopes.merge(Image.with_content_types(vals))
    @scopes = @scopes.joins(**joins) if joins
  end

  def initialize_img_vote_parameters
    add_presence_condition(Image[:vote_cache], params[:with_votes])
    add_range_condition(Image[:vote_cache], params[:quality])
    add_range_condition(
      Observation[:vote_cache], params[:confidence],
      { observation_images: :observations }
    )
  end

  def add_img_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }
    return if handle_img_content_search!

    @scopes = @scopes.joins(observation_images: :observations)
    initialize_advanced_search
  end

  # Perform content search as an observation query, then
  # coerce into images.
  def handle_img_content_search!
    return false if params[:content].blank?

    # self.executor = lambda do |args|
    #   execute_img_content_search(args)
    # end
    @scopes = @scopes.merge(
      Image.search_content_and_associations(params[:content])
    )
  end

  # def execute_img_content_search(args)
  #   # [Sorry, yes, this is a mess. But I don't expect this type of search
  #   # to survive much longer. Image searches are in desperate need of
  #   # critical revision for performance concerns, anyway. -JPH 20210809]
  #   args2 = args.except(:select, :order, :group)
  #   params2 = params.except(:by)
  #   ids = Query.lookup(:Observation, params2).result_ids(args2)
  #   ids = clean_id_set(ids)
  #   args2 = args.dup
  #   extend_join(args2) << :observation_images
  #   extend_where(args2) << "observation_images.observation_id IN (#{ids})"
  #   model.connection.select_rows(query(args2))
  # end

  # def add_img_inside_observation_conditions
  #   return unless params[:observation] && params[:outer]

  #   obs = find_cached_parameter_instance(Observation, :observation)
  #   @title_args[:observation] = obs.unique_format_name
  #   imgs = image_set(obs)
  #   where << "images.id IN (#{imgs})"
  #   self.order = "FIND_IN_SET(images.id,'#{imgs}') ASC"
  #   self.outer_id = params[:outer]
  #   skip_observations_with_no_images
  # end

  # def image_set(obs)
  #   ids = []
  #   ids << obs.thumb_image_id if obs.thumb_image_id
  #   ids += obs.image_ids - [obs.thumb_image_id]
  #   clean_id_set(ids)
  # end

  # # Tell outer query to skip observations with no images!
  # def skip_observations_with_no_images
  #   self.tweak_outer_query = lambda do |outer|
  #     extend_where(outer.params) <<
  #       "observations.thumb_image_id IS NOT NULL"
  #   end
  # end
end
