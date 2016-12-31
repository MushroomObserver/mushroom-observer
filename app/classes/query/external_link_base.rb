class Query::ExternalLinkBase < Query::Base
  def model
    ExternalLink
  end

  def parameter_declarations
    super.merge(
      created_at?:     [:time],
      updated_at?:     [:time],
      users?:          [User],
      observations?:   [Observation],
      external_sites?: [ExternalSite],
      url?:            :string
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    initialize_model_do_objects_by_id(:observations)
    initialize_model_do_objects_by_name(
      ExternalSite, :external_sites, "external_links.external_site_id"
    )
    initialize_model_do_search(:url, :url)
    super
  end

  def default_order
    "url"
  end
end
