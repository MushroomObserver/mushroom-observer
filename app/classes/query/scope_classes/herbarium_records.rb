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
    initialize_has_notes_parameter
    initialize_notes_has_parameter
    initialize_initial_det_parameter
    initialize_accession_number_parameter
    add_pattern_condition
    super
  end

  def initialize_association_parameters
    initialize_herbaria_parameter([])
    initialize_observations_parameter
  end

  def initialize_has_notes_parameter
    return unless params[:has_notes]

    @scopes = @scopes.has_notes(params[:has_notes])
  end

  def initialize_notes_has_parameter
    return unless params[:notes_has]

    @scopes = @scopes.notes_has(params[:notes_has])
  end

  def initialize_initial_det_parameter
    return unless params[:initial_det]

    @scopes = @scopes.initial_det(params[:initial_det])
  end

  def initialize_accession_number_parameter
    return unless params[:accession_number]

    @scopes = @scopes.accession_number(params[:accession_number])
  end

  def search_fields
    (HerbariumRecord[:initial_det] + HerbariumRecord[:accession_number] +
     HerbariumRecord[:notes].coalesce(""))
  end

  def self.default_order
    :herbarium_label
  end
end
