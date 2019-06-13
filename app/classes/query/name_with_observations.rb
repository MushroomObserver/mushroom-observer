class Query::NameWithObservations < Query::NameBase
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      old_by?:           :string,
      date?:             [:date],
      projects?:         [:string],
      herbaria?:         [:string],
      herbarium_records?: [:string],
      confidence?:       [:float],
      is_collection_location?: :boolean,
      has_location?:     :boolean,
      has_name?:         :boolean,
      has_sequences?:    { boolean: [true] },
      has_notes_fields?: [:string],
      north?:            :float,
      south?:            :float,
      east?:             :float,
      west?:             :float
    ).merge(content_filter_parameter_declarations(Observation))
  end

  def initialize_flavor
    add_join(:observations)
    add_owner_and_time_stamp_conditions("observations")
    add_date_condition("observations.when", params[:date])
    initialize_projects_parameter
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    add_range_condition("observations.vote_cache", params[:confidence])
    initialize_is_collection_location_parameter
    initialize_has_location_parameter
    initialize_has_name_parameter
    initialize_has_notes_parameter
    add_has_notes_fields_condition(params[:has_notes_fields])
    add_join(:observations, :comments) if params[:has_comments]
    add_join(:observations, :sequences) if params[:has_sequences]
    initialize_comments_has_parameter
    add_search_condition("observations.notes", params[:notes_has])
    add_bounding_box_conditions_for_observations
    initialize_content_filters(Observation)
    super
  end

  def initialize_projects_parameter
    add_id_condition(
      "observations_projects.project_id",
      lookup_projects_by_name(params[:projects]),
      :observations, :observations_projects
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

  def initialize_is_collection_location_parameter
    add_boolean_condition(
      "observations.is_collection_location IS TRUE",
      "observations.is_collection_location IS FALSE",
      params[:is_collection_location]
    )
  end

  def initialize_has_location_parameter
    add_boolean_condition(
      "observations.location_id IS NOT NULL",
      "observations.location_id IS NULL",
      params[:has_location]
    )
  end

  def initialize_has_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      "names.rank <= #{genus} or names.rank = #{group}",
      "names.rank > #{genus} and names.rank < #{group}",
      params[:has_name]
    )
  end

  def initialize_has_notes_parameter
    add_boolean_condition(
      "observations.notes != #{escape(Observation.no_notes_persisted)}",
      "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      params[:has_notes]
    )
  end

  def initialize_comments_has_parameter
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :observations, :comments
    )
  end

  def add_join_to_locations!
    add_join(:observations, :locations!)
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :all, params_with_old_by_restored)
  end
end
