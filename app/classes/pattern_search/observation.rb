# frozen_string_literal: true

module PatternSearch
  # base class for Searches for Observations meeting conditions in a Pattern
  class Observation < Base
    PARAMS = {
      # dates / times
      when: [:date, :parse_date_range],
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      # names
      name: [:names, :parse_list_of_names],
      exclude_consensus: [:exclude_consensus, :parse_boolean], # of_look_alikes
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
      user: [:by_users, :parse_list_of_users],
      field_slip: [:field_slips, :parse_list_of_strings],

      # numeric
      confidence: [:confidence, :parse_confidence],

      east: [:east, :parse_longitude],
      north: [:north, :parse_latitude],
      south: [:south, :parse_latitude],
      west: [:west, :parse_longitude],

      # booleanish
      has_comments: [:has_comments, :parse_yes],
      has_public_lat_lng: [:has_public_lat_lng, :parse_boolean],
      has_name: [:has_name, :parse_boolean],
      has_notes: [:has_notes, :parse_boolean],
      has_images: [:has_images, :parse_boolean],
      is_collection_location: [:is_collection_location, :parse_boolean],
      lichen: [:lichen, :parse_boolean],
      has_sequence: [:has_sequences, :parse_yes],
      has_specimen: [:has_specimen, :parse_boolean]
    }.freeze

    def self.params
      PARAMS
    end

    delegate :params, to: :class

    def self.model
      ::Observation
    end

    delegate :model, to: :class

    def build_query
      super
      hack_name_query
      default_to_including_synonyms_and_subtaxa
      put_nsew_params_in_box
      put_names_and_modifiers_in_hash
    end

    private

    # Temporary hack to get include_subtaxa/synonyms to work.
    # This converts any search that *looks like* a name search into
    # an actual name search. NOTE: This affects the index title.
    def hack_name_query
      return unless args[:pattern].present? && args[:names].empty? &&
                    (is_pattern_a_name? || any_taxa_modifiers_present?)

      args[:names] = args[:pattern]
      args.delete(:pattern)
    end

    def default_to_including_synonyms_and_subtaxa
      return if args[:names].empty?

      args[:include_subtaxa] = true if args[:include_subtaxa].nil?
      args[:include_synonyms] = true if args[:include_synonyms].nil?
    end

    def is_pattern_a_name?
      pat = ::Name.parse_name(args[:pattern])&.search_name || args[:pattern]
      ::Name.where(text_name: pat).or(::Name.where(search_name: pat)).any?
    end

    def any_taxa_modifiers_present?
      !args[:include_subtaxa].nil? ||
        !args[:include_synonyms].nil? ||
        !args[:include_all_name_proposals].nil? ||
        !args[:exclude_consensus].nil?
    end

    def put_nsew_params_in_box
      north, south, east, west = args.values_at(:north, :south, :east, :west)
      box = { north:, south:, east:, west: }
      return if box.compact.blank?

      box = validate_box(box)
      args[:in_box] = box
      args.except!(:north, :south, :east, :west)
    end

    def validate_box(box)
      validator = Mappable::Box.new(**box)
      return box if validator.valid?

      check_for_missing_box_params
      # Just fix the box if they've got it swapped
      if args[:south] > args[:north]
        box = box.merge(north: args[:south], south: args[:north])
      end
      box
    end

    def check_for_missing_box_params
      [:north, :south, :east, :west].each do |term|
        next if args[term].present?

        raise(PatternSearch::MissingValueError.new(var: term))
      end
    end
  end
end
