# frozen_string_literal: true

class Query::HerbariumRecords < Query::Base
  def model
    HerbariumRecord
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [HerbariumRecord],
      by_users: [User],
      has_notes: :boolean,
      notes_has: :string,
      initial_dets: [:string],
      initial_det_has: :string,
      accession_numbers: [:string],
      accession_number_has: :string,
      herbaria: [Herbarium],
      observations: [Observation],
      pattern: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_exact_match_parameters
    initialize_search_parameters
    add_pattern_condition
    super
  end

  def initialize_association_parameters
    initialize_herbaria_parameter([])
    initialize_observations_parameter
  end

  def initialize_boolean_parameters
    add_boolean_condition("COALESCE(herbarium_records.notes,'') != ''",
                          "COALESCE(herbarium_records.notes,'') = ''",
                          params[:has_notes])
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
