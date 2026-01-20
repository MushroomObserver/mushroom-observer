# frozen_string_literal: true

class Query::FieldSlips < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [FieldSlip])
  query_attr(:by_users, [User])
  query_attr(:code, [:string])
  query_attr(:code_has, [:string])
  query_attr(:observation, [Observation])
  query_attr(:project, [Project])
  query_attr(:projects, [Project])

  def self.default_order
    :code_then_date
  end
end
