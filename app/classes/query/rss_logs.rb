# frozen_string_literal: true

class Query::RssLogs < Query::Base
  include Query::Params::Filters
  include Query::Initializers::Filters

  def model
    RssLog
  end

  def self.parameter_declarations
    super.merge(
      updated_at: [:time],
      id_in_set: [RssLog],
      type: :string
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(content_filter_parameter_declarations(Location))
  end

  def initialize_flavor
    add_time_condition("rss_logs.updated_at", params[:updated_at])
    initialize_type_parameter
    add_id_in_set_condition
    initialize_content_filters_for_rss_log(Observation)
    initialize_content_filters_for_rss_log(Location)
    super
  end

  def types
    @types ||= (params[:type] || "all").to_s.split
  end

  def initialize_type_parameter
    return if types.include?("all")

    types = self.types
    types &= RssLog::ALL_TYPE_TAGS.map(&:to_s)

    @where << if types.empty?
                "FALSE"
              else
                types.map do |type|
                  "rss_logs.#{type}_id IS NOT NULL"
                end.join(" OR ")
              end
  end

  def self.default_order
    "updated_at"
  end
end
