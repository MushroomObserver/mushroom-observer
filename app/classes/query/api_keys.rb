# frozen_string_literal: true

class Query::APIKeys < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:notes_has, :string)

  def self.default_order
    :created_at
  end
end
