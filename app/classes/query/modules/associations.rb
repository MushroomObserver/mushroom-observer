# frozen_string_literal: true

module Query
  module Modules
    # Helper methods for turning Query parameters into SQL conditions.
    module Associations
      def add_where_condition(table, vals, *)
        return if vals.empty?

        loc_col   = "#{table}.location_id"
        where_col = "#{table}.where"
        ids       = clean_id_set(lookup_locations_by_name(vals))
        cond      = "#{loc_col} IN (#{ids})"
        vals.each do |val|
          if /\D/.match?(val)
            pattern = clean_pattern(val)
            cond += " OR #{where_col} LIKE '%#{pattern}%'"
          end
        end
        @where << cond
        add_joins(*)
      end

      def add_at_location_condition(table = model.table_name)
        return unless params[:location]

        location = find_cached_parameter_instance(Location, :location)
        title_args[:location] = location.title_display_name
        @where << "#{table}.location_id = '#{location.id}'"
      end

      def add_is_collection_location_condition_for_locations
        return unless model == Location

        where << "observations.is_collection_location IS TRUE"
      end

      def add_for_project_condition(table = model.table_name, joins = nil)
        return if params[:project].blank?

        project = find_cached_parameter_instance(Project, :project)
        @title_tag = :query_title_for_project
        @title_args[:project] = project.title
        where << "#{table}.project_id = '#{params[:project]}'"
        add_is_collection_location_condition_for_locations
        add_join(*joins) if joins
      end
    end
  end
end
