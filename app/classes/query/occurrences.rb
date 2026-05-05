# frozen_string_literal: true

class Query::Occurrences < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Occurrence])
  query_attr(:by_users, [User])
  query_attr(:observations, [Observation])
  query_attr(:field_slips, [FieldSlip])

  def self.default_order
    :created_at
  end
end
