# frozen_string_literal: true

module PatternSearch
  # base class for Searches for Observations meeting conditions in a Pattern
  class Observation < Base
    PARAMS = {
      # dates / times
      date: [:date, :parse_date_range],
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      # names
      name: [:names, :parse_list_of_names],
      exclude_consensus: [:exclude_consensus, :parse_boolean],
      include_subtaxa: [:include_subtaxa, :parse_boolean],
      include_synonyms: [:include_synonyms, :parse_boolean],
      include_all_name_proposals: [:include_all_name_proposals, :parse_boolean],

      # strings / lists
      comments: [:comments_has, :parse_string],
      has_field: [:has_notes_fields, :parse_string],
      herbarium: [:herbaria, :parse_list_of_herbaria],
      list: [:species_lists, :parse_list_of_species_lists],
      location: [:locations, :parse_list_of_locations],
      notes: [:notes_has, :parse_string],
      project: [:projects, :parse_list_of_projects],
      project_lists: [:project_lists, :parse_list_of_projects],
      region: [:region, :parse_list_of_strings],
      user: [:users, :parse_list_of_users],

      # numeric
      confidence: [:confidence, :parse_confidence],

      east: [:east, :parse_longitude],
      north: [:north, :parse_latitude],
      south: [:south, :parse_latitude],
      west: [:west, :parse_longitude],

      # booleanish
      has_comments: [:has_comments, :parse_yes],
      has_location: [:has_location, :parse_boolean],
      has_name: [:has_name, :parse_boolean],
      has_notes: [:has_notes, :parse_boolean],
      images: [:has_images, :parse_boolean],
      is_collection_location: [:is_collection_location, :parse_boolean],
      lichen: [:lichen, :parse_boolean],
      sequence: [:has_sequences, :parse_yes],
      specimen: [:has_specimen, :parse_boolean]
    }.freeze

    def self.params
      PARAMS
    end

    def params
      self.class.params
    end

    def self.model
      ::Observation
    end

    def model
      self.class.model
    end

    def build_query
      super
      hack_name_query
      default_to_including_synonyms_and_subtaxa
    end

    private

    # Temporary hack to get include_subtaxa/synonyms to work.
    # Will rip out when we do away with pattern search query flavor.
    # This converts any search that *looks like* a name search into
    # an actual name search.
    def hack_name_query
      return unless flavor == :pattern_search &&
                    args[:names].empty? &&
                    (is_pattern_a_name? || any_taxa_modifiers_present?)

      self.flavor = :all
      args[:names] = args[:pattern]
      args.delete(:pattern)
    end

    def default_to_including_synonyms_and_subtaxa
      return if args[:names].empty? ||
                any_taxa_modifiers_present?

      args[:include_subtaxa] = true
      args[:include_synonyms] = true
    end

    def is_pattern_a_name?
      Name.where(search_name: args[:pattern].to_s).any?
    end

    def any_taxa_modifiers_present?
      !args[:include_subtaxa].nil? ||
      !args[:include_synonyms].nil? ||
      !args[:include_all_name_proposals].nil?
    end
  end
end
