# frozen_string_literal: true

class Query::ExternalLinks < Query::Base
  def model
    ExternalLink
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_range: [:integer],
      users: [User],
      observations: [Observation],
      external_sites: [ExternalSite],
      url: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    initialize_observations_parameter(:external_links)
    ids = lookup_external_sites_by_name(params[:external_sites])
    add_id_condition("external_links.external_site_id", ids)
    add_search_condition("external_links.url", params[:url])
    super
  end

  def self.default_order
    "url"
  end
end
