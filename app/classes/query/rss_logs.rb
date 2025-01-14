# frozen_string_literal: true

class Query::RssLogs < Query::Base
  include Query::Params::ContentFilters
  include Query::Initializers::ContentFilters

  def model
    RssLog
  end

  def parameter_declarations
    super.merge(
      updated_at?: [:time],
      type?: :string,
      ids?: [RssLog]
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(content_filter_parameter_declarations(Location))
  end

  def initialize_flavor
    add_sort_order_to_title
    add_time_condition("rss_logs.updated_at", params[:updated_at])
    initialize_type_parameter
    add_ids_condition
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
    types &= RssLog.all_types
    where << if types.empty?
               "FALSE"
             else
               types.map do |type|
                 "rss_logs.#{type}_id IS NOT NULL"
               end.join(" OR ")
             end
  end

  def coerce_into_article_query
    do_coerce(:Article)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def coerce_into_observation_query
    do_coerce(:Observation)
  end

  def coerce_into_project_query
    do_coerce(:Project)
  end

  def coerce_into_species_list_query
    do_coerce(:SpeciesList)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, params_minus_type.merge(by: :rss_log))
  end

  def params_minus_type
    return params unless params.key?(:type)

    params2 = params.dup
    params2.delete(:type)
    params2
  end

  def self.default_order
    "updated_at"
  end
end
