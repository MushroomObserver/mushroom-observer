# frozen_string_literal: true

class Query::ScopeClasses::HerbariumRecords < Query::BaseAR
  def model
    HerbariumRecord
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [HerbariumRecord],
      by_users: [User],
      herbaria: [Herbarium],
      observations: [Observation],
      pattern: :string,
      has_notes: :boolean,
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
    add_boolean_condition(
      HerbariumRecord[:notes].coalesce("").not_eq(nil),
      HerbariumRecord[:notes].coalesce("").eq(nil),
      params[:has_notes]
    )
  end

  def initialize_exact_match_parameters
    add_exact_match_condition(HerbariumRecord[:initial_det],
                              params[:initial_det])
    add_exact_match_condition(HerbariumRecord[:accession_number],
                              params[:accession_number])
  end

  def initialize_search_parameters
    add_simple_search_condition(:notes_has)
    add_simple_search_condition(:initial_det)
    add_simple_search_condition(:accession_number)
  end

  def search_fields
    (HerbariumRecord[:initial_det] + HerbariumRecord[:accession_number] +
     HerbariumRecord[:notes].coalesce(""))
  end

  def self.default_order
    :herbarium_label
  end
end
