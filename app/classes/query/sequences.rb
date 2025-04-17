# frozen_string_literal: true

class Query::Sequences < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Sequence])
  query_attr(:by_users, [User])
  query_attr(:observations, [Observation])
  query_attr(:locus, [:string])
  query_attr(:locus_has, :string)
  query_attr(:archive, [:string])
  query_attr(:accession, [:string])
  query_attr(:accession_has, :string)
  query_attr(:notes_has, :string)
  query_attr(:pattern, :string)
  query_attr(:observation_query, { subquery: :Observation })

  def alphabetical_by
    @alphabetical_by ||= Sequence[:locus]
  end

  def self.default_order
    :created_at
  end
end
