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
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_misspellings
      initialize_model_do_deprecated
      initialize_model_do_objects_by_name(Name, :names, :id)
      initialize_model_do_objects_by_name(
        Name, :synonym_names, :id, filter: :synonyms
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, :id, filter: :all_children
      )
      initialize_model_do_locations("observations", join: :observations)
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: { observations: :observations_species_lists }
      )
      initialize_model_do_rank
      initialize_model_do_boolean(
        :is_deprecated,
        "names.deprecated IS TRUE",
        "names.deprecated IS FALSE"
      )
      initialize_model_do_boolean(
        :has_synonyms,
        "names.synonym_id IS NOT NULL",
        "names.synonym_id IS NULL"
      )
      initialize_model_do_boolean(
        :ok_for_export,
        "names.ok_for_export IS TRUE",
        "names.ok_for_export IS FALSE"
      )
      unless params[:text_name_has].blank?
        initialize_model_do_search(:text_name_has, "text_name")
      end
      initialize_model_do_boolean(
        :has_author,
        'LENGTH(COALESCE(names.author,"")) > 0',
        'LENGTH(COALESCE(names.author,"")) = 0'
      )
      unless params[:author_has].blank?
        initialize_model_do_search(:author_has, "author")
      end
      initialize_model_do_boolean(
        :has_citation,
        'LENGTH(COALESCE(names.citation,"")) > 0',
        'LENGTH(COALESCE(names.citation,"")) = 0'
      )
      unless params[:citation_has].blank?
        initialize_model_do_search(:citation_has, "citation")
      end
      initialize_model_do_boolean(
        :has_classification,
        'LENGTH(COALESCE(names.classification,"")) > 0',
        'LENGTH(COALESCE(names.classification,"")) = 0'
      )
      unless params[:classification_has].blank?
        initialize_model_do_search(:classification_has, "classification")
      end
      initialize_model_do_boolean(
        :has_notes,
        'LENGTH(COALESCE(names.notes,"")) > 0',
        'LENGTH(COALESCE(names.notes,"")) = 0'
      )
      unless params[:notes_has].blank?
        initialize_model_do_search(:notes_has, "notes")
      end
      add_join(:comments) if params[:has_comments]
      unless params[:comments_has].blank?
        initialize_model_do_search(
          :comments_has,
          "CONCAT(comments.summary,COALESCE(comments.comment,''))"
        )
        add_join(:comments)
      end
      add_join(:observations) if params[:has_observations]
      initialize_model_do_boolean(
        :has_default_desc,
        "names.description_id IS NOT NULL",
        "names.description_id IS NULL"
      )
      if params[:join_desc] == :default
        add_join(:'name_descriptions.default')
      elsif (params[:join_desc] == :any) ||
            !params[:desc_type].blank? ||
            !params[:desc_project].blank? ||
            !params[:desc_creator].blank? ||
            !params[:desc_content].blank?
        add_join(:name_descriptions)
      end
      initialize_model_do_enum_set(
        :desc_type,
        "name_descriptions.source_type",
        Description.all_source_types,
        :integer
      )
      initialize_model_do_objects_by_name(
        Project, :desc_project, "name_descriptions.project_id"
      )
      initialize_model_do_objects_by_name(
        User, :desc_creator, "name_descriptions.user_id"
      )
      fields = NameDescription.all_note_fields
      fields = fields.map { |f| "COALESCE(name_descriptions.#{f},'')" }
      initialize_model_do_search(:desc_content, "CONCAT(#{fields.join(",")})")
      initialize_content_filters(Name)
      super
    end

    def default_order
      "name"
    end
  end
end
