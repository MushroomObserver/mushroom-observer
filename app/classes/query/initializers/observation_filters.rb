module Query
  module Initializers
    # Handles user content-filtering parameters common to all observation
    # queries and their coerced equivalents for image, location and name.
    module ObservationFilters
      def observation_filter_parameter_declarations
        ContentFilter.query_parameter_declarations_for_model(Observation)
      end

      def any_observation_filter_is_on?
        ContentFilter.by_model(Observation).any? do |fltr|
          !params[fltr.sym].blank?
        end
      end

      def initialize_observation_filters_for_rss_log
        conds = observation_filter_sql_conds
        @where << "observations.id IS NULL OR (#{and_clause(*conds)})"
      end

      def initialize_observation_filters
        @where += observation_filter_sql_conds
      end

      def observation_filter_sql_conds
        ContentFilter.by_model(Observation).
          each_with_object([]) do |fltr, conds|
            next if params[fltr.sym].blank?
            conds.push(*send(:"observation_filter_sql_conds_for_#{fltr.sym}",
                             params[fltr.sym]))
          end
      end

      def observation_filter_sql_conds_for_has_images(val)
        ["observations.thumb_image_id IS #{val ? "NOT NULL" : "NULL"}"]
      end

      def observation_filter_sql_conds_for_has_specimen(val)
        ["observations.specimen IS #{val ? "TRUE" : "FALSE"}"]
      end

      def observation_filter_sql_conds_for_location_filter(val)
        val  = Location.reverse_name_if_necessary(val)
        val1 = escape(val)
        val2 = escape("%, #{val}")
        [%(
          IF(
            observations.location_id IS NOT NULL,
            observations.location_id IN (
              SELECT id FROM locations WHERE name = #{val1} OR name LIKE #{val2}
            ),
            observations.where = #{val1} OR observations.where LIKE #{val2}
          )
        )]
      end
    end
  end
end
