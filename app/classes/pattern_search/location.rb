# frozen_string_literal: true

module PatternSearch
  # Search where results returned are Locations
  class Location < Base
    PARAMS = {
      # dates / times
      created: [:created_at, :parse_date_range],
      modified: [:updated_at, :parse_date_range],

      # strings / lists
      region: [:region, :parse_list_of_strings],
      user: [:by_users, :parse_list_of_users],
      notes: [:notes_has, :parse_string],

      # numeric - bounding box
      east: [:east, :parse_longitude],
      north: [:north, :parse_latitude],
      south: [:south, :parse_latitude],
      west: [:west, :parse_longitude],

      # booleanish
      has_notes: [:has_notes, :parse_boolean],
      has_observations: [:has_observations, :parse_yes],
      has_descriptions: [:has_descriptions, :parse_yes]
    }.freeze

    def self.params
      PARAMS
    end

    delegate :params, to: :class

    def self.model
      ::Location
    end

    delegate :model, to: :class

    def build_query
      super
      put_nsew_params_in_box
    end
  end
end
