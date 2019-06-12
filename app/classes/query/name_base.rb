module Query
  # Common code shared by all name queries.
  class NameBase < Query::Base
    include Query::Initializers::ContentFilters

    def model
      Name
    end

    def parameter_declarations
      super.merge(
        created_at?:         [:time],
        updated_at?:         [:time],
        users?:              [User],
        names?:              [:string],
        synonym_names?:      [:string],
        children_names?:     [:string],
        misspellings?:       { string: [:no, :either, :only] },
        deprecated?:         { string: [:either, :no, :only] },
        has_synonyms?:       :boolean,
        locations?:          [:string],
        species_lists?:      [:string],
        rank?:               [{ string: Name.all_ranks }],
        is_deprecated?:      :boolean,
        text_name_has?:      :string,
        has_author?:         :boolean,
        author_has?:         :string,
        has_citation?:       :boolean,
        citation_has?:       :string,
        has_classification?: :boolean,
        classification_has?: :string,
        has_notes?:          :boolean,
        notes_has?:          :string,
        has_comments?:       { boolean: [true] },
        comments_has?:       :string,
        has_observations?:   { boolean: [true] },
        has_default_desc?:   :boolean,
        join_desc?:          { string: [:default, :any] },
        desc_type?:          [{string: [Description.all_source_types]}],
        desc_project?:       [:string],
        desc_creator?:       [User],
        desc_content?:       :string,
        ok_for_export?:      :boolean
      ).merge(content_filter_parameter_declarations(Name))
    end

    def initialize_flavor
      unless is_a?(LocationWithObservations)
        initialize_created_at_condition
        initialize_updated_at_condition
        initialize_users_condition
        initialize_has_notes_condition
        initialize_notes_has_condition
        initialize_has_comments_condition
        initialize_comments_has_condition
      end
      initialize_misspellings_condition
      initialize_deprecated_condition
      initialize_names_condition
      initialize_rank_condition
      initialize_synonym_names_condition
      initialize_children_names_condition
      initialize_observations_condition
      initialize_species_lists_condition
      initialize_is_deprecated_condition
      initialize_has_synonyms_condition
      initialize_ok_for_export_condition
      initialize_text_name_has_condition
      initialize_has_author_condition
      initialize_author_has_condition
      initialize_has_citation_condition
      initialize_citation_has_condition
      initialize_has_classification_condition
      initialize_classification_has_condition
      initialize_has_observations_condition
      initialize_has_default_desc_condition
      initialize_join_desc_condition
      initialize_desc_type_condition
      initialize_desc_project_condition
      initialize_desc_creator_condition
      initialize_desc_content_condition
      initialize_content_filters(Name)
      super
    end

    def initialize_created_at_condition
      initialize_model_do_time(:created_at)
    end

    def initialize_updated_at_condition
      initialize_model_do_time(:updated_at)
    end

    def initialize_users_condition
      initialize_model_do_objects_by_id(:users)
    end

    def initialize_has_notes_condition
      initialize_model_do_boolean(
        :has_notes,
        'LENGTH(COALESCE(names.notes,"")) > 0',
        'LENGTH(COALESCE(names.notes,"")) = 0'
      )
    end

    def initialize_notes_has_condition
      return unless params[:notes_has].present?

      initialize_model_do_search(:notes_has, "notes")
    end

    def initialize_has_comments_condition
      return unless params[:comments_has].present?

      initialize_model_do_search(
        :comments_has,
        "CONCAT(comments.summary,COALESCE(comments.comment,''))"
      )
      add_join(:comments)
    end

    def initialize_comments_has_condition
      return unless params[:has_comments]

      add_join(:comments)
    end

    def initialize_misspellings_condition
      initialize_model_do_misspellings
    end

    def initialize_deprecated_condition
      initialize_model_do_deprecated
    end

    def initialize_names_condition
      initialize_model_do_objects_by_name(Name, :names, :id)
    end

    def initialize_rank_condition
      initialize_model_do_rank
    end

    def initialize_synonym_names_condition
      initialize_model_do_objects_by_name(
        Name, :synonym_names, :id, filter: :synonyms
      )
    end

    def initialize_children_names_condition
      initialize_model_do_objects_by_name(
        Name, :children_names, :id, filter: :all_children
      )
    end

    def initialize_observations_condition
      initialize_model_do_locations("observations", join: :observations)
    end

    def initialize_species_lists_condition
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: { observations: :observations_species_lists }
      )
    end

    def initialize_is_deprecated_condition
      initialize_model_do_boolean(
        :is_deprecated,
        "names.deprecated IS TRUE",
        "names.deprecated IS FALSE"
      )
    end

    def initialize_has_synonyms_condition
      initialize_model_do_boolean(
        :has_synonyms,
        "names.synonym_id IS NOT NULL",
        "names.synonym_id IS NULL"
      )
    end

    def initialize_ok_for_export_condition
      initialize_model_do_boolean(
        :ok_for_export,
        "names.ok_for_export IS TRUE",
        "names.ok_for_export IS FALSE"
      )
    end

    def initialize_text_name_has_condition
      return unless params[:text_name_has].present?

      initialize_model_do_search(:text_name_has, "text_name")
    end

    def initialize_has_author_condition
      initialize_model_do_boolean(
        :has_author,
        'LENGTH(COALESCE(names.author,"")) > 0',
        'LENGTH(COALESCE(names.author,"")) = 0'
      )
    end

    def initialize_author_has_condition
      return unless params[:author_has].present?

      initialize_model_do_search(:author_has, "author")
    end

    def initialize_has_citation_condition
      initialize_model_do_boolean(
        :has_citation,
        'LENGTH(COALESCE(names.citation,"")) > 0',
        'LENGTH(COALESCE(names.citation,"")) = 0'
      )
    end

    def initialize_citation_has_condition
      return unless params[:citation_has].present?

      initialize_model_do_search(:citation_has, "citation")
    end

    def initialize_has_classification_condition
      initialize_model_do_boolean(
        :has_classification,
        'LENGTH(COALESCE(names.classification,"")) > 0',
        'LENGTH(COALESCE(names.classification,"")) = 0'
      )
    end

    def initialize_classification_has_condition
      return unless params[:classification_has].present?

      initialize_model_do_search(:classification_has, "classification")
    end

    def initialize_has_observations_condition
      return unless params[:has_observations]

      add_join(:observations)
    end

    def initialize_has_default_desc_condition
      initialize_model_do_boolean(
        :has_default_desc,
        "names.description_id IS NOT NULL",
        "names.description_id IS NULL"
      )
    end

    def initialize_join_desc_condition
      if params[:join_desc] == :default
        add_join(:'name_descriptions.default')
      elsif (params[:join_desc] == :any) ||
            params[:desc_type].present? ||
            params[:desc_project].present? ||
            params[:desc_creator].present? ||
            params[:desc_content].present?
        add_join(:name_descriptions)
      end
    end

    def initialize_desc_type_condition
      initialize_model_do_enum_set(
        :desc_type,
        "name_descriptions.source_type",
        Description.all_source_types,
        :integer
      )
    end

    def initialize_desc_project_condition
      initialize_model_do_objects_by_name(
        Project, :desc_project, "name_descriptions.project_id"
      )
    end

    def initialize_desc_creator_condition
      initialize_model_do_objects_by_name(
        User, :desc_creator, "name_descriptions.user_id"
      )
    end

    def initialize_desc_content_condition
      fields = NameDescription.all_note_fields
      fields = fields.map { |f| "COALESCE(name_descriptions.#{f},'')" }
      initialize_model_do_search(:desc_content, "CONCAT(#{fields.join(",")})")
    end

    def default_order
      "name"
    end
  end
end
