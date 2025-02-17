# frozen_string_literal: true

module PatternSearch
  # Search where results returned are Names
  class Name < Base
    PARAMS = {
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      deprecated: [:is_deprecated, :parse_boolean],
      has_synonyms: [:with_synonyms, :parse_boolean],
      lichen: [:lichen, :parse_boolean],
      include_misspellings: [:misspellings, :parse_yes_no_both],
      include_subtaxa: [:include_subtaxa, :parse_boolean],
      include_synonyms: [:include_synonyms, :parse_boolean],
      rank: [:rank, :parse_rank_range],

      has_author: [:with_author, :parse_boolean],
      has_citation: [:with_citation, :parse_boolean],
      has_classification: [:with_classification, :parse_boolean],
      has_notes: [:with_notes, :parse_boolean],
      has_comments: [:with_comments, :parse_yes],
      has_description: [:with_default_desc, :parse_boolean],
      has_observations: [:with_observations, :parse_yes],

      author: [:author_has, :parse_string],
      citation: [:citation_has, :parse_string],
      classification: [:classification_has, :parse_string],
      notes: [:notes_has, :parse_string],
      comments: [:comments_has, :parse_string]
    }.freeze

    def self.params
      PARAMS
    end

    # List of fields that are displayed in the search form.
    # Autocompleters have id fields, and range fields are concatenated.
    def self.fields
      params.keys + [
        :created_range, :modified_range, :rank_range, :pattern
      ]
    end

    def self.fields_with_dates
      [:created, :modified]
    end

    def self.fields_with_range
      [:created, :modified, :rank]
    end

    def self.fields_with_ids
      []
    end

    # hash of required: fields
    def self.fields_with_requirements
      {}
    end

    def params
      self.class.params
    end

    def self.model
      ::Name
    end

    def model
      self.class.model
    end

    def build_query
      super

      # This converts any search that *looks like* a name search into
      # an actual name search. NOTE: This affects the index title.
      return unless args[:include_subtaxa].present? ||
                    args[:include_synonyms].present?

      args[:names] = args[:pattern]
      args.delete(:pattern)
    end
  end
end
