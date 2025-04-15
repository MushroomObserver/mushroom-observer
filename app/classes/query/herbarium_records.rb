# frozen_string_literal: true

class Query::HerbariumRecords < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [HerbariumRecord],
      by_users: [User],
      has_notes: :boolean,
      notes_has: :string,
      initial_det: [:string],
      initial_det_has: :string,
      accession: [:string],
      accession_has: :string,
      herbaria: [Herbarium],
      observations: [Observation],
      pattern: :string
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`

  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= HerbariumRecord
  end

  def alphabetical_by
    @alphabetical_by ||= HerbariumRecord[:initial_det]
  end

  def self.default_order
    :herbarium_label
  end
end
