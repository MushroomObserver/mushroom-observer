# frozen_string_literal: true
module PatternSearch
  # base class for Searches for Observations meeting conditions in a Pattern
  class Observation < Base
    # Disable cop to preserve alignment for easier reading of parser value
    # rubocop:disable Layout/AlignHash
    PARAMS = {
      # dates / times
      date:            [:date,             :parse_date_range],
      created:         [:created_at,       :parse_date_range],
      modified:        [:updated_at,       :parse_date_range],

      # strings/ lists
      child_of:        [:children_names,   :parse_list_of_names],
      name:            [:names,            :parse_list_of_names],
      synonym_of:      [:synonym_names,    :parse_list_of_names],

      comments:        [:comments_has,     :parse_string],
      has_field:       [:has_notes_fields, :parse_string],
      herbarium:       [:herbaria,         :parse_list_of_herbaria],
      list:            [:species_lists,    :parse_list_of_species_lists],
      location:        [:locations,        :parse_list_of_locations],
      notes:           [:notes_has,        :parse_string],
      project:         [:projects,         :parse_list_of_projects],
      region:          [:region,           :parse_string],
      user:            [:users,            :parse_list_of_users],

      # numeric
      confidence:      [:confidence,       :parse_confidence],

      east:            [:east,             :parse_longitude],
      north:           [:north,            :parse_latitude],
      south:           [:south,            :parse_latitude],
      west:            [:west,             :parse_longitude],

      # booleanish
      has_comments:    [:has_comments,     :parse_yes],
      has_location:    [:has_location,     :parse_boolean],
      has_name:        [:has_name,         :parse_boolean],
      has_notes:       [:has_notes,        :parse_boolean],
      images:          [:has_images,       :parse_boolean],
      is_collection_location: [:is_collection_location, :parse_boolean],
      lichen:          [:lichen,           :parse_boolean],
      sequence:        [:has_sequences,    :parse_yes],
      specimen:        [:has_specimen,     :parse_boolean]
    }.freeze
    # rubocop:enable Layout/AlignHash

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
  end
end
