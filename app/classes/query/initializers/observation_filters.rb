module Query
  module Initializers
    # Handles user content-filtering parameters common to all observation
    # queries and their coerced equivalents for image, location and name.
    module ObservationFilters
      include ::ContentFilter

      # Hash of filter_parameters, each pair like:  has_images?: :string
      # Uses filter definitions in ContentFilter to populate hash.
      def observation_filter_parameter_declarations
        observation_filter_keys.each_with_object({}) do |f_sym, decs|
          decs["#{f_sym.to_s}?".to_sym] = :string
        end
      end

      # Lets application controller easily check if we need to apply user's content
      # filter parameters to the current query.
      def observation_filter_input
        true
      end

      # Lets ApplicationController check whether to add default filters to
      # current query; defaults are added unless query already has
      # observation filter params, even if those filters are off.
      # This allows for overriding of default filters.
      def has_obs_filter_params?
        observation_filter_keys.any? {|k| params[k] != nil}
      end

      # Lets Query::RssLogBase check whether to add filtered observations
      # to the current query.
      def any_observation_filter_is_on?
        on_obs_filters.any?
      end

      # array of filters which are on (applied) in this query
      def on_obs_filters
        observation_filter_keys.each_with_object([]) do |filter, ons|
          ons << filter if is_on?(filter)
        end
      end

      # Does params[:x] == one of x's on_vals?  For example:
      # is_on?(:has_images) is true if params[:has_images] == "NOT NULL" || "NULL"
      def is_on?(filter_sym)
        return unless params[filter_sym]
        filter = send(filter_sym)
        filter[:on_vals].include?(params[filter_sym])
      end

      def initialize_observation_filters_for_rss_log
        conds = obs_filter_sql_conds
        return if conds.empty?

        # and_clause splat wraps a single arg in an array; so if only 1 condition,
        # call and_clause with a string (rather than 1-element array).
        conds = conds.first if conds.size == 1
        @where << "observations.id IS NULL OR (#{and_clause(conds)})"
      end

      def initialize_observation_filters
        @where += obs_filter_sql_conds
      end

      # array of literal sql conditions to be included in query
      def obs_filter_sql_conds
        on_obs_filters.each_with_object([]) do |filter_sym, conds|
          filter = send(filter_sym)
          conds << filter[:sql_cond]
        end
      end
    end
  end
end
