# frozen_string_literal: true

class Query::ExternalLinks < Query::BaseAR
  def model
    @model ||= ExternalLink
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [ExternalLink],
      url_has: :string,
      by_users: [User],
      external_sites: [ExternalSite],
      observations: [Observation]
    )
  end

  def self.default_order
    :url
  end
end
