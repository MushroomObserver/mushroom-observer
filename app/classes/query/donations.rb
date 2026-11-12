# frozen_string_literal: true

class Query::Donations < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])

  def self.default_order
    :created_at
  end
end
