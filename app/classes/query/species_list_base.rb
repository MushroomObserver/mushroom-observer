# frozen_string_literal: true

module Query
  # Methods to validate parameters and initialize Query's that return
  # SpeciesList's
  class SpeciesListBase < Query::Base
    include Query::Initializers::Names

    def model
      SpeciesList
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        date?: [:date],
        users?: [User],
        ids?: [SpeciesList],
        locations?: [:string],
        projects?: [:string],
        title_has?: :string,
        with_notes?: :boolean,
        notes_has?: :string,
        with_comments?: { boolean: [true] },
        comments_has?: :string,
        pattern?: :string,
        project?: Project,
        by_user?: User
      ).merge(names_parameter_declarations)
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("species_lists")
      add_date_condition("species_lists.when", params[:date])
      add_pattern_condition
      add_ids_condition
      add_by_user_condition("species_lists")
      add_for_project_condition
      initialize_name_parameters(:species_list_observations, :observations)
      initialize_association_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      super
    end

    def add_pattern_condition
      add_search_condition(search_fields, params[:pattern])
      add_join(:locations!)
      super
    end

    def add_for_project_condition
      return if params[:project].blank?

      project = find_cached_parameter_instance(Project, :project)
      @title_tag = :query_title_for_project
      @title_args[:project] = project.title
      where << "project_species_lists.project_id = '#{params[:project]}'"
      add_join("project_species_lists")
    end

    def initialize_association_parameters
      add_where_condition("species_lists", params[:locations])
      add_id_condition(
        "project_species_lists.project_id",
        lookup_projects_by_name(params[:projects]),
        :project_species_lists
      )
    end

    def initialize_boolean_parameters
      add_boolean_condition(
        "LENGTH(COALESCE(species_lists.notes,'')) > 0",
        "LENGTH(COALESCE(species_lists.notes,'')) = 0",
        params[:with_notes]
      )
      add_join(:comments) if params[:with_comments]
    end

    def initialize_search_parameters
      add_search_condition(
        "species_lists.title",
        params[:title_has]
      )
      add_search_condition(
        "species_lists.notes",
        params[:notes_has]
      )
      add_search_condition(
        "CONCAT(comments.summary,COALESCE(comments.comment,''))",
        params[:comments_has],
        :comments
      )
    end

    def search_fields
      "CONCAT(" \
        "species_lists.title," \
        "COALESCE(species_lists.notes,'')," \
        "IF(locations.id,locations.name,species_lists.where)" \
        ")"
    end

    def self.default_order
      "title"
    end
  end
end
