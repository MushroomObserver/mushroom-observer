# frozen_string_literal: true

module PatternSearch
  # Search where results returned are Names
  class Name < Base
    PARAMS = {
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      deprecated: [:is_deprecated, :parse_boolean],
      with_synonyms: [:with_synonyms, :parse_boolean],
      lichen: [:lichen, :parse_boolean],
      include_misspellings: [:misspellings, :parse_yes_no_both],
      include_subtaxa: [:include_subtaxa, :parse_boolean],
      include_synonyms: [:include_synonyms, :parse_boolean],
      rank: [:rank, :parse_rank_range],

      with_author: [:with_author, :parse_boolean],
      with_citation: [:with_citation, :parse_boolean],
      with_classification: [:with_classification, :parse_boolean],
      with_notes: [:with_notes, :parse_boolean],
      with_comments: [:with_comments, :parse_yes],
      with_description: [:with_default_desc, :parse_boolean],
      with_observations: [:with_observations, :parse_yes],

      author: [:author_has, :parse_string],
      citation: [:citation_has, :parse_string],
      classification: [:classification_has, :parse_string],
      notes_has: [:notes_has, :parse_string],
      comments_has: [:comments_has, :parse_string]
    }.freeze

    def self.params
      PARAMS
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

      # Temporary hack to get include_subtaxa/synonyms to work.
      # Will rip out when we do away with pattern search query flavor.
      if flavor == :pattern_search &&
         (!args[:include_subtaxa].nil? || !args[:include_synonyms].nil?)
        self.flavor = :all
        args[:names] = args[:pattern]
        args.delete(:pattern)
      end
    end
  end
end
