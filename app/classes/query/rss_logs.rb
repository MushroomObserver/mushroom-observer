# frozen_string_literal: true

class Query::RssLogs < Query::BaseAR
  include Query::Params::Filters
  # include Query::Initializers::Filters

  def model
    @model ||= RssLog
  end

  def self.parameter_declarations
    super.merge(
      updated_at: [:time],
      id_in_set: [RssLog],
      type: :string
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(content_filter_parameter_declarations(Location))
  end

  def self.default_order
    :updated_at
  end
end
