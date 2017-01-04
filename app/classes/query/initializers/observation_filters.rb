module Query
  module Initializers
    # Handles user content-filtering parameters common to all observation
    # queries and their coerced equivalents for image, location and name.
    module ObservationFilters
      def observation_filter_parameter_declarations
        {
          has_specimen?: :boolean,
          has_images?:   :boolean
        }
      end

      # Lets Query::RssLogBase check whether to add filtered observations
      # to the current query.
      def any_observation_filter_is_on?
        !params[:has_specimen].nil? || !params[:has_images].nil?
      end

      def initialize_observation_filters_for_rss_log
        conds = obs_filter_sql_conds
        @where << "observations.id IS NULL OR (#{and_clause(*conds)})"
      end

      def initialize_observation_filters
        @where += obs_filter_sql_conds
      end

      # Array of literal sql conditions to be included in query.
      def obs_filter_sql_conds
        conds = []
        unless params[:has_specimen].nil?
          val = params[:has_specimen] ? "TRUE" : "FALSE"
          conds << "observations.specimen IS #{val}"
        end
        unless params[:has_images].nil?
          val = params[:has_images] ? "NOT NULL" : "NULL"
          conds << "observations.thumb_image_id IS #{val}"
        end
        conds
      end
    end
  end
end
