# frozen_string_literal: true

class Query::RssLogs < Query::BaseNew
  include Query::Params::Filters

  def self.parameter_declarations
    super.merge(
      updated_at: [:time],
      id_in_set: [RssLog],
      type: :string
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(content_filter_parameter_declarations(Location)) # .
      # merge(content_filter_parameter_declarations(Name))
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= RssLog
  end

  def self.default_order
    :updated_at
  end
end
