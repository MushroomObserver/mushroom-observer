# frozen_string_literal: true

class Query::HerbariumRecords < Query::Base
  def model
    HerbariumRecord
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_range: [:integer],
      users: [User],
      herbaria: [Herbarium],
      herbarium: Herbarium,
      observation: Observation,
      observations: [Observation],
      pattern: :string,
      with_notes: :boolean,
      initial_det: [:string],
      accession_number: [:string],
      notes_has: :string,
      initial_det_has: :string,
      accession_number_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_pattern_condition
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_exact_match_parameters
    initialize_search_parameters
    super
  end

  def initialize_association_parameters
    add_in_herbarium_condition
    initialize_herbaria_parameter([])
    add_for_observation_condition
    initialize_observations_parameter
  end

  def add_in_herbarium_condition
    return if params[:herbarium].blank?

    herbarium = find_cached_parameter_instance(Herbarium, :herbarium)
    @title_tag = :query_title_in_herbarium
    @title_args[:herbarium] = herbarium.name
    where << "herbarium_records.herbarium_id = '#{herbarium.id}'"
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

  def search_fields
    "CONCAT(" \
      "herbarium_records.initial_det," \
      "herbarium_records.accession_number," \
      "COALESCE(herbarium_records.notes,'')" \
      ")"
  end

  def self.default_order
    "herbarium_label"
  end
end
