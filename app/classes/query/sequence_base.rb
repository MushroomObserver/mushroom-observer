class Query::SequenceBase < Query::Base
  def model
    Sequence
  end

  def parameter_declarations
    super.merge(sequence_parameter_declarations).
      merge(observation_parameter_declarations)
  end

  def sequence_parameter_declarations
    {
      created_at?:    [:time],
      updated_at?:    [:time],
      observations?:  [Observation],
      users?:         [User],
      locus?:         [:string],
      archive?:       [:string],
      accession?:     [:string],
      locus_has?:     :string,
      accession_has?: :string,
      notes_has?:     :string
    }
  end

  def observation_parameter_declarations
    {
      obs_date?:         [:date],
      observers?:        [User],
      names?:            [:string],
      synonym_names?:    [:string],
      children_names?:   [:string],
      locations?:        [:string],
      herbaria?:         [:string],
      herbarium_records?: [:string],
      projects?:         [:string],
      species_lists?:    [:string],
      confidence?:       [:float],
      north?:            :float,
      south?:            :float,
      east?:             :float,
      west?:             :float,
      is_collection_location?: :boolean,
      has_images?:       :boolean,
      has_name?:         :boolean,
      has_specimen?:     :boolean,
      has_obs_notes?:    :boolean,
      has_notes_fields?: [:string],
      obs_notes_has?:    :string
    }
  end

  def initialize_flavor
    initialize_sequence_filters
    initialize_observation_filters
    super
  end

  def initialize_sequence_filters
    add_owner_and_time_stamp_conditions("sequences")
    add_id_condition("sequences.observation_id", params[:observations])
    # Leaving out bases because some formats allow spaces and other "garbage"
    # delimiters which could interrupt the subsequence the user is searching
    # for.  Users would probably not understand why the search fails to find
    # some sequences because of this.
    add_exact_match_condition("sequences.locus", params[:locus])
    add_exact_match_condition("sequences.archive", params[:archive])
    add_exact_match_condition("sequences.accession", params[:accession])
    add_search_condition("sequences.locus", params[:locus_has])
    add_search_condition("sequences.accession", params[:accession_has])
    add_search_condition("sequences.notes", params[:notes_has])
  end

  def initialize_observation_filters
    add_date_condition("observations.when", params[:obs_date], :observations)
    initialize_observers_parameter
    initialize_names_parameter
    initialize_synonym_names_parameter
    initialize_children_names_parameter
    initialize_locations_parameter
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    initialize_projects_parameter
    initialize_species_lists_parameter
    initialize_confidence_parameter
    initialize_is_collection_location_parameter
    initialize_has_images_parameter
    initialize_has_specimen_parameter
    initialize_has_name_parameter
    initialize_has_obs_notes_parameter
    add_has_notes_fields_condition(params[:has_notes_fields], :observations)
    initialize_obs_notes_has_parameter
    initialize_model_do_observation_bounding_box
    # add_join(:observations) if @where.any? { |w| w.include?("observations.") }
  end

  def initialize_observers_parameter
    add_id_condition(
      "observations.user_id",
      lookup_users_by_name(params[:observers]),
      :observations
    )
  end

  def initialize_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:names]),
      :observations
    )
  end

  def initialize_synonym_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:synonym_names], :synonyms),
      :observations
    )
  end

  def initialize_children_names_parameter
    add_id_condition(
      "observations.name_id",
      lookup_names_by_name(params[:children_names], :all_children),
      :observations
    )
  end

  def initialize_locations_parameter
    add_id_condition(
      "observations.location_id",
      lookup_locations_by_name(params[:locations]),
      :observations
    )
  end

  def initialize_herbaria_parameter
    add_id_condition(
      "herbarium_records.herbarium_id",
      lookup_herbaria_by_name(params[:herbaria]),
      :observations, :herbarium_records_observations, :herbarium_records
    )
  end

  def initialize_herbarium_records_parameter
    add_id_condition(
      "herbarium_records_observations.herbarium_record_id",
      lookup_herbarium_records_by_name(params[:herbarium_records]),
      :observations, :herbarium_records_observations
    )
  end

  def initialize_projects_parameter
    add_id_condition(
      "observations_projects.project_id",
      lookup_projects_by_name(params[:projects]),
      :observations, :observations_projects
    )
  end

  def initialize_species_lists_parameter
    add_id_condition(
      "observations_species_lists.species_list_id",
      lookup_species_lists_by_name(params[:species_lists]),
      :observations, :observations_species_lists
    )
  end

  def initialize_confidence_parameter
    add_range_condition("observations.vote_cache", params[:confidence],
                        :observations)
  end

  def initialize_is_collection_location_parameter
    add_boolean_condition(
      "observations.is_collection_location IS TRUE",
      "observations.is_collection_location IS FALSE",
      :is_collection_location,
      :observations
    )
  end

  def initialize_has_images_parameter
    add_boolean_condition(
      "observations.thumb_image_id IS NOT NULL",
      "observations.thumb_image_id IS NULL",
      :has_images,
      :observations
    )
  end

  def initialize_has_specimen_parameter
    add_boolean_condition(
      "observations.specimen IS TRUE",
      "observations.specimen IS FALSE",
      :has_specimen,
      :observations
    )
  end

  def initialize_has_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      "names.rank <= #{genus} or names.rank = #{group}",
      "names.rank > #{genus} and names.rank < #{group}",
      :has_name,
      :observations, :names
    )
  end

  def initialize_has_obs_notes_parameter
    add_boolean_condition(
      "observations.notes != #{escape(Observation.no_notes_persisted)}",
      "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      :has_obs_notes,
      :observations
    )
  end

  def initialize_obs_notes_has_parameter
    add_search_condition("observations.notes", params[:obs_notes_has],
                         :observations)
  end

  def default_order
    "created_at"
  end
end
