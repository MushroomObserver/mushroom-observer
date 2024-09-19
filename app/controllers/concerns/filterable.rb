# frozen_string_literal: true

#
#  = Filterable Concern
#
#  This is a module of reusable methods included by controllers that handle
#  "faceted" pattern searches per model, with separate inputs for each keyword.
#
#  We're translating the params hash into the format that the user would have
#  typed into the search box if they knew how to do that, because that's what
#  the PatternSearch class expects to parse. The PatternSearch class then
#  unpacks, validates and re-translates all these params into the actual params
#  used by the Query class. This may seem roundabout: of course we do know the
#  Query param names in advance, so we could theoretically just pass the values
#  directly into Query and render the index. But we'd still have to be able to
#  validate the input, and give messages for all the possible errors there.
#  PatternSearch class handles all that.
#
################################################################################

module Filterable
  extend ActiveSupport::Concern

  # Rubocop is incorrect here. This is a concern, not a class.
  # rubocop:disable Metrics/BlockLength
  included do
    def formatted_pattern_search_string
      sift_and_restructure_form_params
      keyword_strings = @sendable_params.map do |key, value|
        "#{key}:#{value}"
      end
      keyword_strings.join(" ")
    end

    # One oddball is `confidence` - the string "0" should not count as a value.
    def sift_and_restructure_form_params
      @keywords = @filter.attributes.to_h.compact_blank.symbolize_keys

      concatenate_range_fields
      @sendable_params = @keywords
      substitute_ids_for_names
      # @storable_params = @keywords
      # set_storable_params
    end

    # Check for `fields_with_range`, and concatenate them if range val present,
    # removing the range field.
    def concatenate_range_fields
      @keywords.each_key do |key|
        next unless fields_with_range.include?(key.to_sym) &&
                    @keywords[:"#{key}_range"].present?

        @keywords[key] = [@keywords[key].to_s.strip,
                          @keywords[:"#{key}_range"].to_s.strip].join("-")
        @keywords.delete(:"#{key}_range")
      end
    end

    # SENDABLE_PARAMS
    # These methods don't modify the original @keywords hash.
    #
    # Controller declares `fields_with_ids` which autocompleter send ids.
    # This method substitutes the ids for the names.
    def substitute_ids_for_names
      @sendable_params.each_key do |key|
        next unless fields_with_ids.include?(key.to_sym) &&
                    @sendable_params[:"#{key}_id"].present?

        @sendable_params[key] = @sendable_params[:"#{key}_id"]
        @sendable_params.delete(:"#{key}_id")
      end
    end

    # STORABLE_PARAMS
    # These methods don't modify the original @keywords hash.
    #
    # Store full strings for all values, including names and locations,
    # so we can repopulate the form with the same values.
    def set_storable_params
      escape_names_and_remove_ids
      escape_locations_and_remove_ids
    end

    # Escape-quote the names, the way the short form requires.
    def escape_names_and_remove_ids
      @storable_params.each_key do |key|
        next unless fields_with_ids.include?(key.to_sym) &&
                    @storable_params[:"#{key}_id"].present?

        list = @storable_params[key].split(",").map(&:strip)
        list = list.map { |name| "\"#{name}\"" }
        @storable_params[key] = list.join(",")
        @storable_params.delete(:"#{key}_id")
      end
    end

    # Escape-quote the locations and their commas.
    def escape_locations_and_remove_ids
      @storable_params.each_key do |key|
        next unless [:location, :region].include?(key.to_sym) &&
                    @storable_params[:"#{key}_id"].present?

        list = @storable_params[key].split(",").map(&:strip)
        list = list.map { |location| "\"#{location.tr(",", "\\,")}\"" }
        @storable_params[key] = list.join(",")
        @storable_params.delete(:"#{key}_id")
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
