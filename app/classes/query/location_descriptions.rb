# frozen_string_literal: true

class Query::LocationDescriptions < Query::Base
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [LocationDescription])
  query_attr(:by_users, [User])
  query_attr(:by_author, User)
  query_attr(:by_editor, User)
  query_attr(:is_public, :boolean)
  query_attr(:content_has, :string)
  query_attr(:locations, [Location])
  query_attr(:location_query, { subquery: :Location })

  def self.default_order
    :name
  end
end
