# frozen_string_literal: true

class Query::Observations < Query::Base # rubocop:disable Metrics/ClassLength
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Filters
  include Query::Initializers::AdvancedSearch

  def model
    Observation
  end

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      date: [:date],
      created_at: [:time],
      updated_at: [:time],

      id_in_set: [Observation],
      by_users: [User],
      has_name: :boolean,
      names: { lookup: [Name],
               include_synonyms: :boolean,
               include_subtaxa: :boolean,
               include_immediate_subtaxa: :boolean,
               exclude_original_names: :boolean,
               include_all_name_proposals: :boolean,
               exclude_consensus: :boolean },
      confidence: [:float],
      needs_naming: :boolean,
      # clade: :string, # content_filter
      # lichen: :boolean, # content_filter

      is_collection_location: :boolean,
      has_public_lat_lng: :boolean,
      location_undefined: { boolean: [true] },
      locations: [Location],
      in_box: { north: :float, south: :float, east: :float, west: :float },
      # region: :string, # content filter

      has_notes: :boolean,
      notes_has: :string,
      has_notes_fields: [:string],
      pattern: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      has_sequences: { boolean: [true] },
      # has_specimen: :boolean, # content filter
      # has_images: :boolean, # content filter

      field_slips: [FieldSlip],
      herbaria: [Herbarium],
      herbarium_records: [HerbariumRecord],
      projects: [Project],
      project_lists: [Project],
      species_lists: [SpeciesList],
      image_query: { subquery: :Image },
      location_query: { subquery: :Location },
      name_query: { subquery: :Name },
      sequence_query: { subquery: :Sequence }
    ).
      merge(content_filter_parameter_declarations(Observation)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    initialize_obs_basic_parameters
    initialize_obs_record_parameters
    initialize_subquery_parameters
    initialize_association_parameters
    initialize_content_filters(Observation)
    add_pattern_condition
    add_advanced_search_conditions
    super
  end

  def initialize_obs_basic_parameters
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions("observations")
    initialize_obs_date_parameter(:date)
  end

  def initialize_obs_record_parameters
    initialize_is_collection_location_parameter
    initialize_has_public_lat_lng_parameter
    add_bounding_box_conditions_for_observations
    initialize_has_notes_parameter
    initialize_notes_has_parameter
    add_has_notes_fields_condition(params[:has_notes_fields])
    initialize_has_name_parameter
    initialize_names_and_related_names_parameters
    add_needs_naming_condition
    initialize_confidence_parameter
  end

  def initialize_association_parameters # rubocop:disable Metrics/AbcSize
    initialize_locations_parameter(:observations, params[:locations])
    initialize_location_undefined_parameter
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    initialize_projects_parameter(:project_observations)
    initialize_project_lists_parameter
    initialize_species_lists_parameter
    initialize_field_slips_parameter
    add_join(:observations, :comments) if params[:has_comments]
    initialize_comments_has_parameter
    add_join(:observations, :sequences) if params[:has_sequences]
  end

  def initialize_obs_date_parameter(param_name = :date)
    add_date_condition("observations.when", params[param_name], :observations)
  end

  def initialize_is_collection_location_parameter
    add_boolean_condition(
      "observations.is_collection_location IS TRUE",
      "observations.is_collection_location IS FALSE",
      params[:is_collection_location],
      :observations
    )
  end

  def initialize_has_public_lat_lng_parameter
    add_boolean_condition(
      "observations.lat IS NOT NULL AND observations.gps_hidden IS FALSE",
      "observations.lat IS NULL OR observations.gps_hidden IS TRUE",
      params[:has_public_lat_lng],
      :observations
    )
  end

  # This param is sent by advanced_search or a user content_filter
  def initialize_has_images_parameter
    add_boolean_condition(
      "observations.thumb_image_id IS NOT NULL",
      "observations.thumb_image_id IS NULL",
      params[:has_images],
      :observations
    )
  end

  # This param is sent by advanced_search or a user content_filter
  def initialize_has_specimen_parameter
    add_boolean_condition(
      "observations.specimen IS TRUE",
      "observations.specimen IS FALSE",
      params[:has_specimen],
      :observations
    )
  end

  def initialize_has_notes_parameter(param_name = :has_notes)
    add_boolean_condition(
      "observations.notes != #{escape(Observation.no_notes_persisted)}",
      "observations.notes  = #{escape(Observation.no_notes_persisted)}",
      params[param_name],
      :observations
    )
  end

  def initialize_notes_has_parameter
    add_search_condition("observations.notes", params[:notes_has])
  end

  def add_has_notes_fields_condition(fields, *)
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

  def initialize_has_name_parameter
    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    add_boolean_condition(
      "names.`rank` <= #{genus} or names.`rank` = #{group}",
      "names.`rank` > #{genus} and names.`rank` < #{group}",
      params[:has_name],
      :observations, :names
    )
  end

  def initialize_names_and_related_names_parameters
    names = params.dig(:names, :lookup)
    return if names.blank?
    return force_empty_results if irreconcilable_naming_parameters?

    ids = lookup_names_by_name(names, related_names_parameters)
    return force_empty_results if ids.blank?

    all_proposals = params.dig(:names, :include_all_name_proposals)
    table = table_for_names(all_proposals)
    add_association_condition("#{table}.name_id", ids)
    add_join(:observations, :namings) if all_proposals
    add_exclude_consensus_condition(ids)
  end

  def add_exclude_consensus_condition(ids)
    return unless params.dig(:names, :exclude_consensus)

    add_not_associated_condition("observations.name_id", ids)
  end

  def table_for_names(all_proposals)
    if all_proposals
      "namings"
    else
      "observations"
    end
  end

  NAMES_EXPANDER_PARAMS = [
    :include_synonyms, :include_subtaxa, :include_immediate_subtaxa,
    :exclude_original_names
  ].freeze

  def related_names_parameters
    return {} unless params[:names]

    params[:names].dup.slice(*NAMES_EXPANDER_PARAMS).compact
  end

  def irreconcilable_naming_parameters?
    params.dig(:names, :exclude_consensus) &&
      !params.dig(:names, :include_all_name_proposals)
  end

  # ------------------------------------------------------------------------

  def add_needs_naming_condition
    return unless params[:needs_naming]

    user = User.current_id
    # 15x faster to use this AR scope to assemble the IDs vs using
    # SQL SELECT DISTINCT
    @where << Observation.needs_naming_and_not_reviewed_by_user(user).
              to_sql.gsub(/^.*?WHERE/, "")
  end

  def initialize_confidence_parameter
    add_range_condition(
      "observations.vote_cache", params[:confidence], :observations
    )
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:names)
    super
  end

  def add_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    initialize_advanced_search
  end

  def initialize_subquery_parameters
    add_subquery_condition(:image_query, { observation_images: :images })
    add_subquery_condition(:location_query, :locations)
    add_subquery_condition(:name_query, :names)
    add_subquery_condition(:sequence_query, :sequences)
  end

  def initialize_location_undefined_parameter
    return unless params[:location_undefined]
    return if params[:regexp] || params[:by_editor]

    @where << "observations.location_id IS NULL"
    @where << "observations.where IS NOT NULL"
    @group = "observations.where"
    @order = "COUNT(observations.where)"
  end

  def initialize_project_lists_parameter
    ids = lookup_lists_for_projects_by_name(params[:project_lists])
    add_association_condition("species_list_observations.species_list_id", ids,
                              :observations, :species_list_observations)
  end

  def initialize_field_slips_parameter
    return unless params[:field_slips]

    add_join(:field_slips)
    ids = lookup_field_slips_by_name(params[:field_slips])
    add_association_condition("field_slips.id", ids, :observations)
  end

  def initialize_comments_has_parameter
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has], :observations, :comments
    )
  end

  def add_join_to_names
    add_join(:names)
  end

  def add_join_to_users
    add_join(:users)
  end

  def add_join_to_locations
    add_join(:locations!)
  end

  def content_join_spec
    :comments
  end

  def search_fields
    "CONCAT(" \
      "names.search_name," \
      "observations.where" \
      ")"
  end

  def self.default_order
    "date"
  end
end
