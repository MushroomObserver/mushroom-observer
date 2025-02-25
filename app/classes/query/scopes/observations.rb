# frozen_string_literal: true

module Query::Scopes::Observations
  def initialize_obs_basic_parameters
    ids_param = model == Observation ? :ids : :obs_ids
    add_ids_condition(Observation, ids_param)
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    initialize_obs_date_parameter(:date)
  end

  # This is just to allow the additional location conditions
  # to be added FOR coerced queries.
  def add_ids_condition(table = model.table_name, ids_param = :ids)
    super
    return if model != Observation

    add_is_collection_location_condition_for_locations
  end

  def initialize_obs_date_parameter(param_name = :date)
    add_join_to_observations
    add_date_condition(Observation[:when], params[param_name])
  end

  def initialize_project_lists_parameter
    add_association_condition(
      # "species_list_observations.species_list_id",
      SpeciesListObservation[:species_list_id],
      lookup_lists_for_projects_by_name(params[:project_lists]),
      joins_through_observations_if_necessary(:species_list_observations)
    )
  end

  def initialize_field_slips_parameter
    return unless params[:field_slips]

    # add_join(:field_slips)
    @scopes = @scopes.joins(:field_slips)
    add_join_to_observations
    add_exact_match_condition(
      # "field_slips.code",
      FieldSlip[:code],
      params[:field_slips]
    )
  end

  def initialize_obs_record_parameters
    initialize_is_collection_location_parameter
    initialize_with_public_lat_lng_parameter
    initialize_with_name_parameter
    initialize_confidence_parameter
    initialize_obs_with_notes_parameter
    add_with_notes_fields_condition(params[:with_notes_fields])
    @scopes = @scopes.joins(observations: :comments) if params[:with_comments]
    @scopes = @scopes.joins(observations: :sequences) if params[:with_sequences]
  end

  def initialize_is_collection_location_parameter
    add_join_to_observations
    add_boolean_column_condition(
      # "observations.is_collection_location IS TRUE",
      # "observations.is_collection_location IS FALSE",
      Observation[:is_collection_location],
      params[:is_collection_location]
    )
  end

  def initialize_with_public_lat_lng_parameter
    add_join_to_observations
    add_boolean_condition(
      # "observations.lat IS NOT NULL AND observations.gps_hidden IS FALSE",
      # "observations.lat IS NULL OR observations.gps_hidden IS TRUE",
      Observation[:lat].not_eq(nil).and(Observation[:gps_hidden].eq(false)),
      Observation[:lat].eq(nil).or(Observation[:gps_hidden].eq(true)),
      params[:with_public_lat_lng]
    )
  end

  def initialize_with_images_parameter
    add_join_to_observations
    add_presence_condition(
      # "observations.thumb_image_id IS NOT NULL",
      # "observations.thumb_image_id IS NULL",
      Observation[:thumb_image_id],
      params[:with_images]
    )
  end

  def initialize_with_specimen_parameter
    add_join_to_observations
    add_boolean_column_condition(
      # "observations.specimen IS TRUE",
      # "observations.specimen IS FALSE",
      Observation[:specimen],
      params[:with_specimen]
    )
  end

  # rubocop:disable Metrics/AbcSize
  def initialize_with_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      # "names.`rank` <= #{genus} or names.`rank` = #{group}",
      # "names.`rank` > #{genus} and names.`rank` < #{group}",
      Name[:rank].lteq(genus).or( Name[:rank].eq(group)),
      Name[:rank].gt(genus).and( Name[:rank].lt(group)),
      params[:with_name],
      joins_through_observations_if_necessary(:names)
    )
  end
  # rubocop:enable Metrics/AbcSize

  def add_needs_naming_condition
    return unless params[:needs_naming]

    add_join_to_observations
    user = User.current_id
    @scopes = @scopes.where(
      Observation.needs_naming_and_not_reviewed_by_user(user)
    )

    # additional filters:
    add_name_in_clade_condition
    add_location_in_region_condition
    # add_by_user_condition
  end

  # from content_filter/clade.rb
  # parse_name and check the already initialize_unfiltered list of
  # observations against observations.classification. Some inefficiency
  # here comes from having to parse the name from a string.
  # NOTE: Write an in_clade autocompleter that passes the name_id as val
  def add_name_in_clade_condition
    return unless params[:in_clade]

    # val = params[:in_clade]
    # name, rank = parse_name(val)
    # conds = if Name.ranks_above_genus.include?(rank)
    #           "observations.text_name = '#{name}' OR " \
    #           "observations.classification REGEXP '#{rank}: _#{name}_'"
    #         else
    #           "observations.text_name = '#{name}' OR " \
    #           "observations.text_name REGEXP '^#{name} '"
    #         end
    # where << conds
    @scopes = @scopes.in_clade(params[:in_clade])
  end

  # def parse_name(val)
  #   name = Name.best_match(val)
  #   return [name.text_name, name.rank] if name

  #   [val, Name.guess_rank(val) || "Genus"]
  # end

  # from content_filter/region.rb, but simpler.
  # includes region itself (i.e., no comma before region in 2nd regex)
  def add_location_in_region_condition
    return unless params[:in_region]

    region = params[:in_region]
    @scopes = if model == Observation
                @scopes.in_region(region)
              else
                @scopes.merge(Observation.in_region(region))
              end
  end

  def initialize_confidence_parameter
    add_join_to_observations
    add_range_condition(Observation[:vote_cache], params[:confidence])
  end

  def initialize_obs_with_notes_parameter(param_name = :with_notes)
    add_join_to_observations
    add_boolean_condition(
      # "observations.notes != #{escape(Observation.no_notes_persisted)}",
      # "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      Observation[:notes].not_eq(Observation.no_notes_persisted),
      Observation[:notes].eq(Observation.no_notes_persisted),
      params[param_name]
    )
  end

  def add_with_notes_fields_condition(fields, joins)
    return if fields.empty?

    add_join_to_observations
    @scopes = if model == Observation
                @scopes.with_notes_fields(fields)
              else
                @scopes.merge(Observation.with_notes_fields(fields))
              end
    @scopes = @scopes.joins(**joins) if joins
  end

  def initialize_obs_search_parameters
    add_search_condition(Observation[:notes], params[:notes_has])
    add_observation_comments_search_condition
    return if model == Observation

    add_join_to_observations
    add_search_condition(Observation[:where], params[:user_where])
  end

  def add_observation_comments_search_condition
    add_search_condition(
      # "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      Comment[:summary] + Comment[:comment].coalesce(""),
      params[:comments_has],
      joins_through_observations_if_necessary(:comments)
    )
  end

  def params_out_to_with_observations_params(pargs)
    pargs = pargs.merge(with_observations: true)
    return pargs if pargs[:ids].blank?

    pargs[:obs_ids] = pargs.delete(:ids)
    pargs
  end

  def params_back_to_observation_params
    pargs = params_with_old_by_restored.except(:with_observations)
    return pargs if pargs[:obs_ids].blank?

    pargs[:ids] = pargs.delete(:obs_ids)
    pargs
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, params_back_to_observation_params)
  end
end
