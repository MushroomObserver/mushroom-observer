# frozen_string_literal: true

class Query::ExternalSites < Query
  query_attr(:id_in_set, [ExternalSite])
  query_attr(:name_has, :string)

  def self.default_order
    :name
  end
end
