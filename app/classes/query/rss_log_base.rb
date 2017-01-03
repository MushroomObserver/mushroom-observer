module Query
  # Code common to all rss log queries.
  class RssLogBase < Query::Base
    include Query::Initializers::ObservationFilters
    include Query::Initializers::LocationFilters

    def model
      RssLog
    end

    def parameter_declarations
      super.merge(
        updated_at?: [:time],
        type?:       :string
      ).merge(observation_filter_parameter_declarations).
        merge(location_filter_parameter_declarations)
    end

    def initialize_flavor
      initialize_model_do_time(:updated_at)
      add_rss_log_type_condition
      initialize_observation_filters_if_any_on
      initialize_location_filters_if_any_on
      super
    end

    def initialize_observation_filters_if_any_on
      return unless any_observation_filter_is_on? &&
                    (types.include?("all") || types.include?("observation"))
      add_join(:observations!)
      initialize_observation_filters_for_rss_log
    end

    def initialize_location_filters_if_any_on
      return unless any_location_filter_is_on? &&
                    (types.include?("all") || types.include?("location"))
      add_join(:locations!)
      initialize_location_filters_for_rss_log
    end

    def default_order
      "updated_at"
    end

    def types
      @rss_log_types ||= (params[:type] || "all").to_s.split
    end

    def add_rss_log_type_condition
      return if types.include?("all")
      types = self.types
      types &= RssLog.all_types
      if types.empty?
        where << "FALSE"
      else
        where << types.map do |type|
          "rss_logs.#{type}_id IS NOT NULL"
        end.join(" OR ")
      end
    end
  end
end
