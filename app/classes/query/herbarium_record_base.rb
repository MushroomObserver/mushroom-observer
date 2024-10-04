# frozen_string_literal: true

class Query::HerbariumRecordBase < Query::Base
  def model
    HerbariumRecord
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      herbaria?: [:string],
      herbarium?: Herbarium,
      observation?: Observation,
      observations?: [:string],
      pattern?: :string,
      with_notes?: :boolean,
      initial_det?: [:string],
      accession_number?: [:string],
      notes_has?: :string,
      initial_det_has?: :string,
      accession_number_has?: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("herbarium_records")
    add_for_observation_condition
    add_in_herbarium_condition
    add_pattern_condition
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_exact_match_parameters
    initialize_search_parameters
    super
  end

  def add_for_observation_condition
    return if params[:observation].blank?

    obs = find_cached_parameter_instance(Observation, :observation)
    @title_tag = :query_title_for_observation
    @title_args[:observation] = obs.unique_format_name
    where << "observation_herbarium_records.observation_id = '#{obs.id}'"
    add_join(:observation_herbarium_records)
  end

  def add_in_herbarium_condition
    return if params[:herbarium].blank?

    herbarium = find_cached_parameter_instance(Herbarium, :herbarium)
    @title_tag = :query_title_in_herbarium
    @title_args[:herbarium] = herbarium.name
    where << "herbarium_records.herbarium_id = '#{herbarium.id}'"
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    add_search_condition(search_fields, params[:pattern])
  end

  def search_fields
    "CONCAT(" \
      "herbarium_records.initial_det," \
      "herbarium_records.accession_number," \
      "COALESCE(herbarium_records.notes,'')" \
      ")"
  end

  def initialize_association_parameters
    add_id_condition("herbarium_records.herbarium_id",
                     lookup_herbaria_by_name(params[:herbaria]))
    add_id_condition("observation_herbarium_records.observation_id",
                     params[:observations], :observation_herbarium_records)
  end

  def initialize_boolean_parameters
    add_boolean_condition("COALESCE(herbarium_records.notes,'') != ''",
                          "COALESCE(herbarium_records.notes,'') = ''",
                          params[:with_notes])
  end

  def initialize_exact_match_parameters
    add_exact_match_condition("herbarium_records.initial_det",
                              params[:initial_det])
    add_exact_match_condition("herbarium_records.accession_number",
                              params[:accession_number])
  end

  def initialize_search_parameters
    add_search_condition("herbarium_records.notes",
                         params[:notes_has])
    add_search_condition("herbarium_records.initial_det",
                         params[:initial_det_has])
    add_search_condition("herbarium_records.accession_number",
                         params[:accession_number_has])
  end

  def self.default_order
    "herbarium_label"
  end
end
