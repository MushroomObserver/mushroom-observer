# frozen_string_literal: true

class Query::ScopeClasses::HerbariumRecords < Query::BaseAR
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
    initialize_matching_scope_parameters
    initialize_association_parameters
    add_pattern_condition
    super
  end

  def initialize_association_parameters
    initialize_herbaria_parameter([])
    initialize_observations_parameter
  end

  def initialize_matching_scope_parameters
    [:has_notes, :notes_has,
     :initial_dets, :initial_det_has,
     :accession_numbers, :accession_number_has].each do |param|
      next unless params[param]

      @scopes = @scopes.send(param, params[param])
    end
  end

  def search_fields
    (HerbariumRecord[:initial_det] + HerbariumRecord[:accession_number] +
     HerbariumRecord[:notes].coalesce(""))
  end

  def self.default_order
    :herbarium_label
  end
end
