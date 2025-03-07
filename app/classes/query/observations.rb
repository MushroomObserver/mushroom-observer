# frozen_string_literal: true

class Query::Observations < Query::Base # rubocop:disable Metrics/ClassLength
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Names
  include Query::Initializers::Filters
  include Query::Initializers::AdvancedSearch
  include Query::Titles::Observations

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
      in_clade: :string,
      in_region: :string,
      locations: [Location],
      in_box: { north: :float, south: :float, east: :float, west: :float },
      is_collection_location: :boolean,
      has_public_lat_lng: :boolean,
      location_undefined: { boolean: [true] },
      has_notes: :boolean,
      notes_has: :string,
      has_notes_fields: [:string],
      pattern: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      has_sequences: { boolean: [true] },
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
    add_sort_order_to_title
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
    add_needs_naming_filter_conditions
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

  def add_needs_naming_condition
    return unless params[:needs_naming]

    user = User.current_id
    # 15x faster to use this AR scope to assemble the IDs vs using
    # SQL SELECT DISTINCT
    @where << Observation.needs_naming_and_not_reviewed_by_user(user).
              to_sql.gsub(/^.*?WHERE/, "")
  end

  def add_needs_naming_filter_conditions
    # additional filters, note these are the same as content filters.
    initialize_in_clade_parameter
    initialize_in_region_parameter
    # add_by_user_condition
  end

  # from content_filter/clade.rb
  # parse_name and check the already initialize_unfiltered list of
  # observations against observations.classification. Some inefficiency
  # here comes from having to parse the name from a string.
  # NOTE: Write an in_clade autocompleter that passes the name_id as val
  def initialize_in_clade_parameter
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

  def initialize_confidence_parameter
    add_range_condition(
      "observations.vote_cache", params[:confidence], :observations
    )
  end

  # from content_filter/region.rb, but simpler.
  # includes region itself (i.e., no comma before region in 2nd regex)
  def initialize_in_region_parameter
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

  def title
    default = super
    observation_query_description || default
  end

  def self.default_order
    "date"
  end
end
