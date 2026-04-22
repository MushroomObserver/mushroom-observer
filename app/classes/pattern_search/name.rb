# frozen_string_literal: true

module PatternSearch
  # Search where results returned are Names
  class Name < Base
    PARAMS = {
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      deprecated: [:deprecated, :parse_boolean],
      has_synonyms: [:has_synonyms, :parse_boolean],
      lichen: [:lichen, :parse_boolean],
      include_misspellings: [:misspellings, :parse_no_include_only],
      include_subtaxa: [:include_subtaxa, :parse_boolean],
      include_synonyms: [:include_synonyms, :parse_boolean],
      rank: [:rank, :parse_rank_range],

      has_author: [:has_author, :parse_boolean],
      has_citation: [:has_citation, :parse_boolean],
      has_classification: [:has_classification, :parse_boolean],
      has_notes: [:has_notes, :parse_boolean],
      has_comments: [:has_comments, :parse_yes],
      has_description: [:has_default_description, :parse_boolean],
      has_observations: [:has_observations, :parse_yes],

      author: [:author_has, :parse_string],
      citation: [:citation_has, :parse_string],
      classification: [:classification_has, :parse_string],
      notes: [:notes_has, :parse_string],
      comments: [:comments_has, :parse_string]
    }.freeze

    def self.params
      PARAMS
    end

    delegate :params, to: :class

    def self.model
      ::Name
    end

    delegate :model, to: :class

    def build_query
      super

      hack_name_query
      put_names_and_modifiers_in_hash
    end

    # This converts any search that *looks like* a name search into
    # an actual name search. NOTE: This affects the index title.
    def hack_name_query
      return unless query_params.include?(:include_subtaxa) ||
                    query_params.include?(:include_synonyms)

      query_params[:names] = query_params[:pattern]
      query_params.delete(:pattern)
    end
  end
end
