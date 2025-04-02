# frozen_string_literal: true

class Query::ExternalSites < Query::Base
  def model
    @model ||= ExternalSite
  end

  def self.parameter_declarations
    super.merge(
      id_in_set: [ExternalSite],
      name_has: :string
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def initialize_flavor
    add_id_in_set_condition
    add_search_condition("external_sites.name", params[:name_has])
    super
  end

  def self.default_order
    "name"
  end
end
