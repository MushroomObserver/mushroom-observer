# frozen_string_literal: true

class Query::Publications < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:full_has, :string)

  def self.default_order
    :name
  end
end
