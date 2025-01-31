# frozen_string_literal: true

class Query::ExternalSites < Query::Base
  def model
    ExternalSite
  end

  def parameter_declarations
    super.merge(
      name: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_search_condition("external_sites.name", params[:name])
    super
  end

  def self.default_order
    "name"
  end
end
