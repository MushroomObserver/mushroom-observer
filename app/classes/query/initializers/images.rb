# frozen_string_literal: true

module Query::Initializers::Images
  def initialize_img_notes_parameters
    add_boolean_condition("LENGTH(COALESCE(images.notes,'')) > 0",
                          "LENGTH(COALESCE(images.notes,'')) = 0",
                          params[:with_notes])
    add_search_condition("images.notes", params[:notes_has])
  end

  def initialize_img_association_parameters
    initialize_observations_parameter
    add_where_condition(:observations, params[:locations],
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
    initialize_ok_for_export_parameter
  end

  def add_image_size_condition(vals, *)
    return if vals.empty?

    min, max = vals
    sizes = Image::ALL_SIZES
    pixels = Image::ALL_SIZES_IN_PIXELS
    if min
      size = pixels[sizes.index(min)]
      @where << "images.width >= #{size} OR images.height >= #{size}"
    end
    if max
      size = pixels[sizes.index(max) + 1]
      @where << "images.width < #{size} AND images.height < #{size}"
    end
    add_joins(*)
  end

  def add_image_type_condition(vals, *)
    return if vals.empty?

    exts  = Image::ALL_EXTENSIONS.map(&:to_s)
    mimes = Image::ALL_CONTENT_TYPES.map(&:to_s) - [""]
    types = vals & exts
    return if vals.empty?

    other = types.include?("raw")
    types -= ["raw"]
    types = types.map { |x| mimes[exts.index(x)] }
    str1 = "images.content_type IN ('#{types.join("','")}')"
    str2 = "images.content_type NOT IN ('#{mimes.join("','")}')"
    @where << if types.empty?
                str2
              elsif other
                "#{str1} OR #{str2}"
              else
                str1
              end
    add_joins(*)
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
