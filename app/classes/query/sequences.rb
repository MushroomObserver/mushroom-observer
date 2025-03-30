# frozen_string_literal: true

class Query::Sequences < Query::BaseNew
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

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Sequence
  end

  def alphabetical_by
    @alphabetical_by ||= Sequence[:locus]
  end

  def self.default_order
    :created_at
  end
end
