# frozen_string_literal: true

class Query::Sequences < Query::BaseAR
  def model
    @model ||= Sequence
  end

  def list_by
    @list_by ||= Sequence[:locus]
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Sequence],
      by_users: [User],
      observations: [Observation],
      locus: [:string],
      locus_has: :string,
      archive: [:string],
      accession: [:string],
      accession_has: :string,
      notes_has: :string,
      pattern: :string,
      observation_query: { subquery: :Observation }
    )
  end

  def self.default_order
    :created_at
  end
end
