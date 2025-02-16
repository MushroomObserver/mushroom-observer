# frozen_string_literal: true

module Query::Initializers::Observations
  def initialize_obs_basic_parameters
    ids_param = model == Observation ? :ids : :obs_ids
    add_ids_condition("observations", ids_param)
    add_owner_and_time_stamp_conditions("observations")
    add_by_user_condition("observations")
    initialize_obs_date_parameter(:date)
  end

  # This is just to allow the additional location conditions
  # to be added FOR coerced queries.
  def add_ids_condition(table = model.table_name, ids = :ids)
    super
    return if model != Observation

    add_is_collection_location_condition_for_locations
  end

  def initialize_obs_date_parameter(param_name = :date)
    add_date_condition(
      "observations.when", params[param_name], :observations
    )
  end

  def initialize_project_lists_parameter
    add_id_condition(
      "species_list_observations.species_list_id",
      lookup_lists_for_projects_by_name(params[:project_lists]),
      :observations, :species_list_observations
    )
  end

  def initialize_field_slips_parameter
    return unless params[:field_slips]

    add_join(:field_slips)
    ids = lookup_field_slips_by_name(params[:field_slips])
    add_id_condition( "field_slips.id", ids, :observations)
  end

  def initialize_obs_record_parameters
    initialize_is_collection_location_parameter
    initialize_with_public_lat_lng_parameter
    initialize_with_name_parameter
    initialize_confidence_parameter
    initialize_obs_with_notes_parameter
    add_with_notes_fields_condition(params[:with_notes_fields])
    add_join(:observations, :comments) if params[:with_comments]
    add_join(:observations, :sequences) if params[:with_sequences]
  end

  def initialize_is_collection_location_parameter
    add_boolean_condition(
      "observations.is_collection_location IS TRUE",
      "observations.is_collection_location IS FALSE",
      params[:is_collection_location],
      :observations
    )
  end

  def initialize_with_public_lat_lng_parameter
    add_boolean_condition(
      "observations.lat IS NOT NULL AND observations.gps_hidden IS FALSE",
      "observations.lat IS NULL OR observations.gps_hidden IS TRUE",
      params[:with_public_lat_lng],
      :observations
    )
  end

  def initialize_with_images_parameter
    add_boolean_condition(
      "observations.thumb_image_id IS NOT NULL",
      "observations.thumb_image_id IS NULL",
      params[:with_images],
      :observations
    )
  end

  def initialize_with_specimen_parameter
    add_boolean_condition(
      "observations.specimen IS TRUE",
      "observations.specimen IS FALSE",
      params[:with_specimen],
      :observations
    )
  end

  def initialize_with_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      "names.`rank` <= #{genus} or names.`rank` = #{group}",
      "names.`rank` > #{genus} and names.`rank` < #{group}",
      params[:with_name],
      :observations, :names
    )
  end

  def add_needs_naming_condition
    return unless params[:needs_naming]

    user = User.current_id
    # 15x faster to use this AR scope to assemble the IDs vs using
    # SQL SELECT DISTINCT
    where << Observation.needs_naming_and_not_reviewed_by_user(user).
             to_sql.gsub(/^.*?WHERE/, "")
  end

  def add_needs_naming_filter_conditions
    # additional filters, note these are the same as content filters.
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

    val = params[:in_clade]
    name, rank = parse_name(val)
    conds = if Name.ranks_above_genus.include?(rank)
              "observations.text_name = '#{name}' OR " \
              "observations.classification REGEXP '#{rank}: _#{name}_'"
            else
              "observations.text_name = '#{name}' OR " \
              "observations.text_name REGEXP '^#{name} '"
            end
    where << conds
  end

  def parse_name(val)
    name = Name.best_match(val)
    return [name.text_name, name.rank] if name

    [val, Name.guess_rank(val) || "Genus"]
  end

  # from content_filter/region.rb, but simpler.
  # includes region itself (i.e., no comma before region in 2nd regex)
  def add_location_in_region_condition
    return unless params[:in_region]

    region = params[:in_region]
    region = Location.reverse_name_if_necessary(region)

    conds =
      if Location.understood_continent?(region)
        countries = Location.countries_in_continent(region).join("|")
        "observations.where REGEXP #{escape(", (#{countries})$")}"
      else
        "observations.where LIKE #{escape("%#{region}")}"
      end
    where << conds
  end

  def initialize_confidence_parameter
    add_range_condition(
      "observations.vote_cache", params[:confidence], :observations
    )
  end

  def initialize_obs_with_notes_parameter(param_name = :with_notes)
    add_boolean_condition(
      "observations.notes != #{escape(Observation.no_notes_persisted)}",
      "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      params[param_name],
      :observations
    )
  end

  def add_with_notes_fields_condition(fields, *)
    return if fields.empty?

    conds = fields.map { |field| notes_field_presence_condition(field) }
    @where << conds.join(" OR ")
    add_joins(*)
  end

  def notes_field_presence_condition(field)
    field = field.dup
    pat = if field.gsub!(/(["\\])/) { '\\\1' }
            "\":#{field}:\""
          else
            ":#{field}:"
          end
    "observations.notes like \"%#{pat}%\""
  end

  def initialize_obs_search_parameters
    add_search_condition("observations.notes", params[:notes_has])
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has], :observations, :comments
    )
    return if model == Observation

    add_search_condition("observations.where", params[:user_where])
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
