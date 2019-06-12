class Query::ImageBase < Query::Base
  def model
    Image
  end

  def parameter_declarations
    super.merge(
      created_at?:           [:time],
      updated_at?:           [:time],
      date?:                 [:date],
      users?:                [User],
      names?:                [:string],
      synonym_names?:        [:string],
      children_names?:       [:string],
      locations?:            [:string],
      observations?:         [Observation],
      projects?:             [:string],
      species_lists?:        [:string],
      has_observation?:      { boolean: [true] },
      size?:                 { string: Image.all_sizes - [:full_size] },
      content_types?:        [{ string: Image.all_extensions }],
      has_notes?:            :boolean,
      notes_has?:            :string,
      copyright_holder_has?: :string,
      license?:              [License],
      has_votes?:            :boolean,
      quality?:              [:float],
      confidence?:           [:float],
      ok_for_export?:        :boolean
    )
  end

  def initialize_flavor
    super
    unless is_a?(ImageWithObservations)
      add_owner_and_time_stamp_conditions("images")
      add_date_condition("images.when", params[:date])
      add_join(:images_observations) if params[:has_observation)
      initialize_has_notes_parameter
      add_search_condition("images.notes", params[:notes_has])
    end
    initialize_observations_parameter
    initialize_names_parameter
    initialize_synonym_names_parameter
    initialize_children_names_parameter
    initialize_locations_parameter
    initialize_projects_parameter
    initialize_species_lists_parameter
    add_image_size_condition(params[:size])
    add_image_type_condition(params[:content_types])
    add_id_condition("images.license_id", params[:license_id])
    initialize_copyright_holder_has_parameter
    initialize_has_votes_parameter
    add_range_condition("images.vote_cache", params[:quality])
    initialize_confidence_parameter
    initialize_ok_for_export_parameter
  end

  def initialize_has_notes_parameter
    add_boolean_condition("LENGTH(COALESCE(images.notes,'')) > 0",
                          "LENGTH(COALESCE(images.notes,'')) = 0",
                          params[:has_notes])
  end

  def initialize_observations_parameter
    add_id_condition("images_observations.observation_id",
                     params[:observations], :images_observations)
  end

  def initialize_names_parameter
    add_id_condition("observations.name_id",
                     lookup_names_by_name(params[:names]),
                     :images_observations, :observations)
  end

  def initialize_synonym_names_parameter
    add_id_condition("observations.name_id",
                     lookup_names_by_name(params[:names], :synonyms),
                     :images_observations, :observations)
  end

  def initialize_children_names_parameter
    add_id_condition("observations.name_id",
                     lookup_names_by_name(params[:names], :all_children),
                     :images_observations, :observations)
  end

  def initialize_locations_parameter
    add_location_condition("observations", params[:locations],
                           :images_observations, :observations)
  end

  def initialize_projects_parameter
    add_id_condition("images_projects.project_id",
                     lookup_projects_by_name(params[:projects]),
                     :images_projects)
  end

  def initialize_species_lists_parameter
    add_id_condition(
      "observations_species_lists.species_list_id"
      lookup_species_lists_by_name(params[:species_lists]),
      :images_observations, :observations, :observations_species_lists
    )
  end

  def initialize_copyright_holder_has_parameter
    add_search_condition("images.copyright_holder",
                         params[:copyright_holder_has])
  end

  def initialize_has_votes_parameter
    add_boolean_condition("images.vote_cache NOT NULL",
                          "images.vote_cache IS NULL",
                          params[:has_votes])
  end

  def initialize_confidence_parameter
    add_range_condition("observations.vote_cache", params[:confidence],
                        :images_observations, :observations)
  end

  def initialize_ok_for_export_parameter
    initialize_model_do_boolean(
      "images.ok_for_export IS TRUE",
      "images.ok_for_export IS FALSE",
      params[:ok_for_export]
    )
  end

  def default_order
    "created_at"
  end
end
