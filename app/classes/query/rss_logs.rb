# frozen_string_literal: true

class Query::RssLogs < Query
  include Query::Params::Filters

  # Commented-out attributes are here so we don't forget they're added
  # via `extra_parameter_declarations` below.
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [RssLog])
  query_attr(:type, :string)
  # query_attr(:clade, :string) # content filter
  # query_attr(:lichen, :boolean) # content filter
  # query_attr(:region, :string) # content filter
  # query_attr(:has_specimen, :boolean) # content filter
  # query_attr(:has_images, :boolean) # content filter

  def self.extra_parameter_declarations
    content_filter_parameter_declarations(Observation).
      merge(content_filter_parameter_declarations(Location)).
      merge(content_filter_parameter_declarations(Name))
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  extra_parameter_declarations.each do |param_name, accepts|
    attribute param_name, :query_param, accepts: accepts
  end

  def self.default_order
    :updated_at
  end
end
