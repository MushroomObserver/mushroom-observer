# frozen_string_literal: true

module Query::Initializers::Images
  def images_per_se_parameter_declarations
    {
      created_at?: [:time],
      updated_at?: [:time],
      date?: [:date],
      ids?: [Image],
      by_user?: User,
      users?: [User],
      locations?: [:string],
      outer?: :query, # for images inside observations
      observation?: Observation, # for images inside observations
      observations?: [Observation],
      project?: Project,
      projects?: [:string],
      species_lists?: [:string],
      with_observation?: { boolean: [true] },
      size?: { string: Image::ALL_SIZES - [:full_size] },
      content_types?: [{ string: Image::ALL_EXTENSIONS }],
      with_notes?: :boolean,
      notes_has?: :string,
      copyright_holder_has?: :string,
      license?: [License],
      with_votes?: :boolean,
      quality?: [:float],
      confidence?: [:float],
      ok_for_export?: :boolean,
      pattern?: :string,
      with_observations?: :boolean
    }
  end

  def initialize_img_notes_parameters
    add_boolean_condition("LENGTH(COALESCE(images.notes,'')) > 0",
                          "LENGTH(COALESCE(images.notes,'')) = 0",
                          params[:with_notes])
    add_search_condition("images.notes", params[:notes_has])
  end

  def initialize_img_association_parameters
    initialize_observations_parameter
    add_where_condition("observations", params[:locations],
                        :observation_images, :observations)
    add_for_project_condition(:project_images)
    initialize_projects_parameter(:project_images, [:project_images])
    initialize_species_lists_parameter(
      :species_list_observations,
      [:observation_images, :observations, :species_list_observations]
    )
    add_id_condition("images.license_id", params[:license])
  end

  def initialize_img_record_parameters
    add_search_condition("images.copyright_holder",
                         params[:copyright_holder_has])
    add_image_size_condition(params[:size])
    add_image_type_condition(params[:content_types])
    add_boolean_condition(
      "images.ok_for_export IS TRUE",
      "images.ok_for_export IS FALSE",
      params[:ok_for_export]
    )
  end

  def initialize_img_vote_parameters
    add_boolean_condition("images.vote_cache IS NOT NULL",
                          "images.vote_cache IS NULL",
                          params[:with_votes])
    add_range_condition("images.vote_cache", params[:quality])
    add_range_condition("observations.vote_cache", params[:confidence],
                        :observation_images, :observations)
  end

  def add_img_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }
    return if handle_img_content_search!

    add_join(:observation_images, :observations)
    initialize_advanced_search
  end

  # Perform content search as an observation query, then
  # coerce into images.
  def handle_img_content_search!
    return false if params[:content].blank?

    self.executor = lambda do |args|
      execute_img_content_search(args)
    end
  end

  def execute_img_content_search(args)
    # [Sorry, yes, this is a mess. But I don't expect this type of search
    # to survive much longer. Image searches are in desperate need of
    # critical revision for performance concerns, anyway. -JPH 20210809]
    args2 = args.except(:select, :order, :group)
    params2 = params.except(:by)
    ids = Query.lookup(:Observation, params2).result_ids(args2)
    ids = clean_id_set(ids)
    args2 = args.dup
    extend_join(args2) << :observation_images
    extend_where(args2) << "observation_images.observation_id IN (#{ids})"
    model.connection.select_rows(query(args2))
  end

  def add_img_inside_observation_conditions
    return unless params[:observation] && params[:outer]

    obs = find_cached_parameter_instance(Observation, :observation)
    @title_args[:observation] = obs.unique_format_name
    imgs = image_set(obs)
    where << "images.id IN (#{imgs})"
    self.order = "FIND_IN_SET(images.id,'#{imgs}') ASC"
    self.outer_id = params[:outer]
    skip_observations_with_no_images
  end

  def image_set(obs)
    ids = []
    ids << obs.thumb_image_id if obs.thumb_image_id
    ids += obs.image_ids - [obs.thumb_image_id]
    clean_id_set(ids)
  end

  # Tell outer query to skip observations with no images!
  def skip_observations_with_no_images
    self.tweak_outer_query = lambda do |outer|
      extend_where(outer.params) <<
        "observations.thumb_image_id IS NOT NULL"
    end
  end
end
