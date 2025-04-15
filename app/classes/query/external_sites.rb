# frozen_string_literal: true

class Query::ExternalSites < Query::Base
  def self.parameter_declarations
    super.merge(
      id_in_set: [ExternalSite],
      name_has: :string
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each do |param_name, accepts|
    attribute param_name, :query_param, accepts: accepts
  end

  def model
    @model ||= ExternalSite
  end

  def self.default_order
    :name
  end
end
