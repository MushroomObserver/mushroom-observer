module Query
  module Initializers
    # Handles user content-filtering parameters common to all location queries.
    module LocationFilters
      def location_filter_parameter_declarations
        ContentFilter.query_parameter_declarations_for_model(Location)
      end

      def any_location_filter_is_on?
        ContentFilter.by_model(Location).any? do |fltr|
          !params[fltr.sym].blank?
        end
      end

      def initialize_location_filters_for_rss_log
        conds = location_filter_sql_conds
        @where << "locations.id IS NULL OR (#{and_clause(*conds)})"
      end

      def initialize_location_filters
        @where += location_filter_sql_conds
      end

      def location_filter_sql_conds
        ContentFilter.by_model(Location).
          each_with_object([]) do |fltr, conds|
            next if params[fltr.sym].blank?
            conds.push(*send(:"location_filter_sql_conds_for_#{fltr.sym}",
                             params[fltr.sym]))
          end
      end

      def location_filter_sql_conds_for_location_filter(val)
        val  = Location.reverse_name_if_necessary(val)
        val1 = escape(val)
        val2 = escape("%, #{val}")
        ["locations.name = #{val1} OR locations.name LIKE #{val2}"]
      end
    end
  end
end
