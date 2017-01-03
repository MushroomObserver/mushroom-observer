module Query
  module Initializers
    # Handles user content filters.
    module ContentFilters
      def content_filter_parameter_declarations(model)
        ContentFilter.by_model(model).each_with_object({}) do |fltr, decs|
          decs[:"#{fltr.sym}?"] = fltr.type
        end
      end

      def initialize_content_filters_for_rss_log(model)
        conds = content_filter_sql_conds(model)
        return unless conds.any?
        table = model.table_name
        add_join(:"#{table}!") # "!" means left outer join
        @where << "#{table}.id IS NULL OR (#{and_clause(*conds)})"
      end

      def initialize_content_filters(model)
        @where += content_filter_sql_conds(model)
      end

      def content_filter_sql_conds(model)
        ContentFilter.by_model(model).
          each_with_object([]) do |fltr, conds|
            next if params[fltr.sym].blank?
            method = :"#{model.type_tag}_content_filter_sql_conds_for_#{fltr.sym}"
            conds.push(*send(method, params[fltr.sym]))
          end
      end

      # --------------------------------------
      #  SQL conditions for content filters.
      # --------------------------------------

      def observation_content_filter_sql_conds_for_has_images(val)
        ["observations.thumb_image_id IS #{val ? "NOT NULL" : "NULL"}"]
      end

      def observation_content_filter_sql_conds_for_has_specimen(val)
        ["observations.specimen IS #{val ? "TRUE" : "FALSE"}"]
      end

      def observation_content_filter_sql_conds_for_location_filter(val)
        val = loc_filter_pat(val)
        [%(
          IF(
            observations.location_id IS NOT NULL,
            observations.location_id IN (
              SELECT id FROM locations WHERE CONCAT(', ', name) LIKE #{val}
            ),
            CONCAT(', ', observations.where) LIKE #{val}
          )
        )]
      end

      def location_content_filter_sql_conds_for_location_filter(val)
        val = loc_filter_pat(val)
        ["CONCAT(', ', locations.name) LIKE #{val}"]
      end

      def loc_filter_pat(val)
        val = Location.reverse_name_if_necessary(val)
        escape("%, #{val}")
      end
    end
  end
end
