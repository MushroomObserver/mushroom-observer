class Query::RssLogBase < Query::Base
  include Query::Initializers::ContentFilters

  def model
    RssLog
  end

  def parameter_declarations
    super.merge(
      updated_at?: [:time],
      type?: :string
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(content_filter_parameter_declarations(Location))
  end

  def initialize_flavor
    add_time_condition("rss_logs.updated_at", params[:updated_at])
    initialize_type_parameter
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

  def default_order
    "updated_at"
  end
end
