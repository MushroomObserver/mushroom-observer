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
        locations?: [:string],
        projects?: [:string],
        title_has?: :string,
        has_notes?: :boolean,
        notes_has?: :string,
        has_comments?: { boolean: [true] },
        comments_has?: :string
      ).merge(names_parameter_declarations)
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("species_lists")
      add_date_condition("species_lists.when", params[:date])
      initialize_name_parameters(:species_list_observations, :observations)
      initialize_association_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      super
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
        params[:has_notes]
      )
      add_join(:comments) if params[:has_comments]
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

    def default_order
      "title"
    end
  end
end
