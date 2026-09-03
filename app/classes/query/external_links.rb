# frozen_string_literal: true

class Query::ExternalLinks < Query
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [ExternalLink])
  query_attr(:by_users, [User], param_alias: :by_user, always_index: false)
  query_attr(:external_sites, [ExternalSite], param_alias: :external_site)
  query_attr(:observations, [Observation], param_alias: :observation)
  query_attr(:url_has, :string)

  def self.default_order
    :url
  end
end
