# frozen_string_literal: true

class Query::Articles < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Article])
  query_attr(:title_has, :string)
  query_attr(:body_has, :string)
  query_attr(:by_users, [User])

  def alphabetical_by
    @alphabetical_by ||= Article[:title]
  end

  def self.default_order
    :updated_at
  end
end
