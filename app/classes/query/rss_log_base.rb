class Query::RssLogBase < Query::Base
  include Query::Initializers::ObservationFilters

  def model
    RssLog
  end

  def parameter_declarations
    super.merge(
      updated_at?: [:time],
      type?:       :string
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    initialize_model_do_time(:updated_at)
    add_rss_log_type_condition
    if any_observation_filter_is_on? &&
       (types.include?("all") || types.include?("observation"))
      add_join(:observations!)
      initialize_observation_filters_for_rss_log
    end
    super
  end

  def default_order
    "updated_at"
  end

  def types
    @rss_log_types ||= (params[:type] || "all").to_s.split
  end

  def add_rss_log_type_condition
    unless types.include?("all")
      types = self.types
      types &= RssLog.all_types
      if types.empty?
        self.where << "FALSE"
      else
        self.where << types.map do |type|
          "rss_logs.#{type}_id IS NOT NULL"
        end.join(" OR ")
      end
    end
  end
end
