# frozen_string_literal: true

module Query
  # base class for Query's which return Names
  class NameBase < Query::Base
    include Query::Initializers::ContentFilters
    include Query::Initializers::Names
    include Query::Initializers::Descriptions
    include Query::Initializers::AdvancedSearch

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
        with_observations?: { boolean: [true] }
      ).merge(content_filter_parameter_declarations(Name)).
        merge(names_parameter_declarations).
        merge(descriptions_parameter_declarations).
        merge(advanced_search_parameter_declarations)
    end
    # rubocop:enable Metrics/MethodLength

    def initialize_flavor
      unless is_a?(Query::NameWithObservations) ||
             is_a?(Query::NameWithDescriptions)
        add_ids_condition
        add_owner_and_time_stamp_conditions
        add_by_user_condition
        add_by_editor_condition
        initialize_name_comments_and_notes_parameters
        initialize_name_parameters_for_name_queries
        add_pattern_condition
        add_name_advanced_search_conditions
        initialize_name_association_parameters
      end
      initialize_taxonomy_parameters
      initialize_name_record_parameters
      initialize_name_search_parameters
      initialize_description_parameters
      initialize_content_filters(Name)
      super
    end

    def add_pattern_condition
      return if params[:pattern].blank?

      add_join(:"name_descriptions.default!")
      super
    end

    def add_join_to_names; end

    def add_join_to_users
      add_join(:observations, :users)
    end

    def add_join_to_locations
      add_join(:observations, :locations!)
    end

    def content_join_spec
      { observations: :comments }
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
