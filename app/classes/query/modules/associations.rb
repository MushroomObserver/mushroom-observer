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

      def add_for_project_condition(table = model.table_name, joins = [table])
        return if params[:project].blank?

        project = find_cached_parameter_instance(Project, :project)
        @title_tag = :query_title_for_project
        @title_args[:project] = project.title
        where << "#{table}.project_id = '#{params[:project]}'"
        add_is_collection_location_condition_for_locations
        add_join(*joins)
      end

      def initialize_projects_parameter(table = :project_observations,
                                        joins = [:observations, table])
        add_id_condition(
          "#{table}.project_id",
          lookup_projects_by_name(params[:projects]),
          *joins
        )
      end

      def add_in_species_list_condition(table = :species_list_observations,
                                        joins = [:observations, table])
        return if params[:species_list].blank?

        spl = find_cached_parameter_instance(SpeciesList, :species_list)
        @title_tag = :query_title_in_species_list
        @title_args[:species_list] = spl.format_name
        where << "#{table}.species_list_id = '#{spl.id}'"
        add_is_collection_location_condition_for_locations
        add_join(*joins)
      end

      def initialize_species_lists_parameter(
        table = :species_list_observations, joins = [:observations, table]
      )
        add_id_condition(
          "#{table}.species_list_id",
          lookup_species_lists_by_name(params[:species_lists]),
          *joins
        )
      end
    end
  end
end
