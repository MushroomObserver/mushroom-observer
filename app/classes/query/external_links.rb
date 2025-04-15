# frozen_string_literal: true

class Query::ExternalLinks < Query::Base
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

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= ExternalLink
  end

  def self.default_order
    :url
  end
end
