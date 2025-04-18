# frozen_string_literal: true

class Query::ExternalLinks < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [ExternalLink])
  query_attr(:by_users, [User])
  query_attr(:external_sites, [ExternalSite])
  query_attr(:observations, [Observation])
  query_attr(:url_has, :string)

  def self.default_order
    :url
  end
end
