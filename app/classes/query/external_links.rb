# frozen_string_literal: true

class Query::ExternalLinks < Query::Base
  def model
    ExternalLink
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [ExternalLink],
      by_users: [User],
      observations: [Observation],
      external_sites: [ExternalSite],
      url_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    initialize_observations_parameter(:external_links)
    ids = lookup_external_sites_by_name(params[:external_sites])
    add_association_condition("external_links.external_site_id", ids)
    add_search_condition("external_links.url", params[:url_has])
    super
  end

  def self.default_order
    "url"
  end
end
