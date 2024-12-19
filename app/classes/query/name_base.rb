# frozen_string_literal: true

module Query
  # base class for Query's which return Names
  class NameBase < Query::Base
    include Query::Initializers::ContentFilters
    include Query::Initializers::Names

    def model
      Name
    end

    # rubocop:disable Metrics/MethodLength
    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        ids?: [Name],
        by_user?: User,
        by_editor?: User,
        users?: [User],
        misspellings?: { string: [:no, :either, :only] },
        deprecated?: { string: [:either, :no, :only] },
        with_synonyms?: :boolean,
        locations?: [:string],
        species_lists?: [:string],
        rank?: [{ string: Name.all_ranks }],
        is_deprecated?: :boolean,
        pattern?: :string,
        text_name_has?: :string,
        with_author?: :boolean,
        author_has?: :string,
        with_citation?: :boolean,
        citation_has?: :string,
        with_classification?: :boolean,
        classification_has?: :string,
        with_notes?: :boolean,
        notes_has?: :string,
        with_comments?: { boolean: [true] },
        comments_has?: :string,
        with_observations?: { boolean: [true] },
        with_default_desc?: :boolean,
        join_desc?: { string: [:default, :any] },
        desc_type?: [{ string: [Description.all_source_types] }],
        desc_project?: [:string],
        desc_creator?: [User],
        desc_content?: :string,
        ok_for_export?: :boolean
      ).merge(content_filter_parameter_declarations(Name)).
        merge(names_parameter_declarations)
    end
    # rubocop:enable Metrics/MethodLength

    def initialize_flavor
      unless is_a?(Query::NameWithObservations) ||
             is_a?(Query::NameWithDescriptions)
        add_ids_condition("names")
        add_owner_and_time_stamp_conditions("names")
        add_by_user_condition("names")
        add_by_editor_condition(:name)
        initialize_comments_and_notes_parameters
        initialize_name_parameters_for_name_queries
        add_pattern_condition
      end
      initialize_taxonomy_parameters
      initialize_boolean_parameters
      initialize_association_parameters
      initialize_search_parameters
      initialize_description_parameters
      initialize_content_filters(Name)
      super
    end

    def initialize_comments_and_notes_parameters
      add_boolean_condition(
        "LENGTH(COALESCE(names.notes,'')) > 0",
        "LENGTH(COALESCE(names.notes,'')) = 0",
        params[:with_notes]
      )
      add_join(:comments) if params[:with_comments]
      add_search_condition(
        "names.notes",
        params[:notes_has]
      )
      add_search_condition(
        "CONCAT(comments.summary,COALESCE(comments.comment,''))",
        params[:comments_has],
        :comments
      )
    end

    def initialize_taxonomy_parameters
      initialize_misspellings_parameter
      initialize_deprecated_parameter
      add_rank_condition(params[:rank])
      initialize_is_deprecated_parameter
      initialize_ok_for_export_parameter
    end

    def initialize_misspellings_parameter
      val = params[:misspellings] || :no
      where << "names.correct_spelling_id IS NULL"     if val == :no
      where << "names.correct_spelling_id IS NOT NULL" if val == :only
    end

    # Not sure how these two are different!
    def initialize_deprecated_parameter
      val = params[:deprecated] || :either
      where << "names.deprecated IS FALSE" if val == :no
      where << "names.deprecated IS TRUE"  if val == :only
    end

    def initialize_is_deprecated_parameter
      add_boolean_condition(
        "names.deprecated IS TRUE",
        "names.deprecated IS FALSE",
        params[:is_deprecated]
      )
    end

    def initialize_ok_for_export_parameter
      add_boolean_condition(
        "names.ok_for_export IS TRUE",
        "names.ok_for_export IS FALSE",
        params[:ok_for_export]
      )
    end

    def initialize_association_parameters
      add_id_condition("observations.id", params[:observations], :observations)
      add_where_condition("observations", params[:locations], :observations)
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :observations, :species_list_observations
      )
    end

    def initialize_boolean_parameters
      initialize_with_synonyms_parameter
      initialize_with_author_parameter
      initialize_with_citation_parameter
      initialize_with_classification_parameter
      add_join(:observations) if params[:with_observations]
    end

    def initialize_with_synonyms_parameter
      add_boolean_condition(
        "names.synonym_id IS NOT NULL",
        "names.synonym_id IS NULL",
        params[:with_synonyms]
      )
    end

    def initialize_with_author_parameter
      add_boolean_condition(
        "LENGTH(COALESCE(names.author,'')) > 0",
        "LENGTH(COALESCE(names.author,'')) = 0",
        params[:with_author]
      )
    end

    def initialize_with_citation_parameter
      add_boolean_condition(
        "LENGTH(COALESCE(names.citation,'')) > 0",
        "LENGTH(COALESCE(names.citation,'')) = 0",
        params[:with_citation]
      )
    end

    def initialize_with_classification_parameter
      add_boolean_condition(
        "LENGTH(COALESCE(names.classification,'')) > 0",
        "LENGTH(COALESCE(names.classification,'')) = 0",
        params[:with_classification]
      )
    end

    def initialize_search_parameters
      add_search_condition("names.text_name", params[:text_name_has])
      add_search_condition("names.author", params[:author_has])
      add_search_condition("names.citation", params[:citation_has])
      add_search_condition("names.classification", params[:classification_has])
    end

    def initialize_description_parameters
      initialize_with_default_desc_parameter
      initialize_join_desc_parameter
      initialize_desc_type_parameter
      initialize_desc_project_parameter
      initialize_desc_creator_parameter
      initialize_desc_content_parameter
    end

    def initialize_with_default_desc_parameter
      add_boolean_condition(
        "names.description_id IS NOT NULL",
        "names.description_id IS NULL",
        params[:with_default_desc]
      )
    end

    def initialize_join_desc_parameter
      if params[:join_desc] == :default
        add_join(:"name_descriptions.default")
      elsif any_param_desc_fields?
        add_join(:name_descriptions)
      end
    end

    def initialize_desc_type_parameter
      add_indexed_enum_condition(
        "name_descriptions.source_type",
        params[:desc_type],
        Description.all_source_types
      )
    end

    def initialize_desc_project_parameter
      add_id_condition(
        "name_descriptions.project_id",
        lookup_projects_by_name(params[:desc_project])
      )
    end

    def initialize_desc_creator_parameter
      add_id_condition(
        "name_descriptions.user_id",
        lookup_users_by_name(params[:desc_creator])
      )
    end

    def initialize_desc_content_parameter
      fields = NameDescription.all_note_fields
      fields = fields.map { |f| "COALESCE(name_descriptions.#{f},'')" }
      fields = "CONCAT(#{fields.join(",")})"
      add_search_condition(fields, params[:desc_content])
    end

    def add_pattern_condition
      return if params[:pattern].blank?

      add_join(:"name_descriptions.default!")
      super
    end

    def search_fields
      fields = [
        "names.search_name",
        "COALESCE(names.citation,'')",
        "COALESCE(names.notes,'')"
      ] + NameDescription.all_note_fields.map do |x|
        "COALESCE(name_descriptions.#{x},'')"
      end
      "CONCAT(#{fields.join(",")})"
    end

    def self.default_order
      "name"
    end

    # --------------------------------------------------------------------------

    private

    def any_param_desc_fields?
      params[:join_desc] == :any ||
        params[:desc_type].present? ||
        params[:desc_project].present? ||
        params[:desc_creator].present? ||
        params[:desc_content].present?
    end
  end
end
