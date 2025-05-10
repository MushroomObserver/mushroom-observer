# frozen_string_literal: true

class Query::FieldSlips < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:by_users, [User])
  query_attr(:projects, [Project])

  def self.default_order
    :code_then_date
  end
end
