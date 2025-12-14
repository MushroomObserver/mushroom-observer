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
      editor: [:by_editor, :parse_user],
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

    private

    def put_nsew_params_in_box
      north, south, east, west = query_params.values_at(:north, :south, :east,
                                                        :west)
      box = { north:, south:, east:, west: }
      return if box.compact.blank?

      box = validate_box(box)
      query_params[:in_box] = box
      query_params.except!(:north, :south, :east, :west)
    end

    def validate_box(box)
      validator = Mappable::Box.new(**box)
      return box if validator.valid?

      check_for_missing_box_params
      # Just fix the box if they've got it swapped
      if query_params[:south] > query_params[:north]
        box = box.merge(north: query_params[:south],
                        south: query_params[:north])
      end
      box
    end

    def check_for_missing_box_params
      [:north, :south, :east, :west].each do |term|
        next if query_params[term].present?

        raise(PatternSearch::MissingValueError.new(var: term))
      end
    end
  end
end
