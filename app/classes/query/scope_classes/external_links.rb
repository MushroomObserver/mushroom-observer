# frozen_string_literal: true

class Query::ScopeClasses::ExternalLinks < Query::BaseAR
  def model
    ExternalLink
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [ExternalLink],
      by_users: [User],
      observations: [Observation],
      external_sites: [ExternalSite],
      url: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    initialize_observations_parameter(:external_links)
    initialize_external_sites_parameter
    add_simple_search_condition(:url)
    super
  end

  def initialize_external_sites_parameter
    return unless params[:external_sites]

    ids = lookup_external_sites_by_name(params[:external_sites])
    add_association_condition(ExternalLink[:external_site_id], ids)
  end

  def self.default_order
    :url
  end
end
