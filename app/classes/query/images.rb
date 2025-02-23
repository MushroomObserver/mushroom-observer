# frozen_string_literal: true

class Query::Images < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
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
      by_users: [User],
      size: [{ string: Image::ALL_SIZES - [:full_size] }],
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
      locations: [Location],
      observations: [Observation],
      projects: [Project],
      species_lists: [SpeciesList],
      with_observations: :boolean,
      observation_query: { subquery: :Observation }
    ).merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    super
    initialize_image_parameters
    initialize_image_association_parameters
    initialize_subquery_parameters
    add_pattern_condition
    add_img_advanced_search_conditions
  end

  def initialize_image_parameters
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_date_condition("images.when", params[:date])
    initialize_img_notes_parameters
    add_search_condition("images.copyright_holder",
                         params[:copyright_holder_has])
    add_image_size_condition(params[:size])
    add_image_type_condition(params[:content_types])
    initialize_ok_for_export_parameter
  end

  def initialize_img_notes_parameters
    add_boolean_condition("LENGTH(COALESCE(images.notes,'')) > 0",
                          "LENGTH(COALESCE(images.notes,'')) = 0",
                          params[:with_notes])
    add_search_condition("images.notes", params[:notes_has])
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

    types, mimes, other = parse_image_type_vals(vals)
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

  def parse_image_type_vals(vals)
    exts  = Image::ALL_EXTENSIONS.map(&:to_s)
    mimes = Image::ALL_CONTENT_TYPES.map(&:to_s) - [""]
    types = vals & exts
    return [types, mimes, nil] if types.empty?

    other = types.include?("raw")
    types -= ["raw"]
    types = types.map { |x| mimes[exts.index(x)] }
    [types, mimes, other]
  end

  def initialize_image_association_parameters
    add_join(:observation_images) if params[:with_observation]
    initialize_images_with_observations
    initialize_observations_parameter
    initialize_image_vote_parameters
    initialize_locations_parameter(:observations, params[:locations],
                                   :observation_images, :observations)
    initialize_projects_parameter(:project_images, [:project_images])
    initialize_species_lists_parameter(
      :species_list_observations,
      [:observation_images, :observations, :species_list_observations]
    )
    add_id_condition("images.license_id", params[:license])
  end

  def initialize_image_vote_parameters
    add_boolean_condition("images.vote_cache IS NOT NULL",
                          "images.vote_cache IS NULL",
                          params[:with_votes])
    add_range_condition("images.vote_cache", params[:quality])
    add_range_condition("observations.vote_cache", params[:confidence],
                        :observation_images, :observations)
  end

  def initialize_subquery_parameters
    add_subquery_condition(:observation_query,
                           { observation_images: :observations })
  end

  def initialize_images_with_observations
    return if params[:with_observations].blank?

    add_join(:observation_images, :observations)
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
    return false if params[:search_content].blank?

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
