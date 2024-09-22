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
    def search_subclass
      PatternSearch.const_get(@filter.class.search_type.capitalize)
    end

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

      remove_invalid_field_combinations
      concatenate_range_fields
      @sendable_params = @keywords
      substitute_ids_for_strings
      # @storable_params = @keywords
      # set_storable_params
    end

    # Passing some fields will raise an error if the required field is missing,
    # so just toss them.
    def remove_invalid_field_combinations
      return unless search_subclass.respond_to?(:fields_with_requirements)

      search_subclass.fields_with_requirements.each do |req, fields|
        next if @keywords[req].present?

        fields.each { |field| @keywords.delete(field) }
      end
    end

    # Check for `fields_with_range`, and concatenate them if range val present,
    # removing the `_range` field.
    def concatenate_range_fields
      return unless search_subclass.respond_to?(:fields_with_range)

      search_subclass.fields_with_range.each do |key|
        next if @keywords[:"#{key}_range"].blank?

        @keywords[key] = [@keywords[key].to_s.strip,
                          @keywords[:"#{key}_range"].to_s.strip].join("-")
        @keywords.delete(:"#{key}_range")
      end
    end

    # SENDABLE_PARAMS - params sent to Query.
    # These methods don't modify the original @keywords.
    #
    # This method substitutes the ids for the strings typed in the form.
    def substitute_ids_for_strings
      search_subclass.fields_with_ids.each do |key|
        next if @sendable_params[:"#{key}_id"].blank?

        @sendable_params[key] = @sendable_params[:"#{key}_id"]
        @sendable_params.delete(:"#{key}_id")
      end
    end

    # STORABLE_PARAMS - params string in session.
    # These methods don't modify the original @keywords.
    #
    # Ideally we'd store full strings for all values, including names and
    # locations, so we can repopulate the form with the same values.
    def set_storable_params
      escape_strings_and_remove_ids
      escape_locations_and_remove_ids
    end

    # Escape-quote the strings, the way the short form requires.
    def escape_strings_and_remove_ids
      search_subclass.fields_with_ids.each do |key|
        # location handled separately
        next if key.to_sym == :location
        next if @storable_params[:"#{key}_id"].blank?

        list = @storable_params[key].split(",").map(&:strip)
        list = list.map { |name| "\"#{name}\"" }
        @storable_params[key] = list.join(",")
        @storable_params.delete(:"#{key}_id")
      end
    end

    # Escape-quote the locations and their commas. We'd prefer to have legible
    # strings in the url, but we're not storing long location strings yet,
    # because the comma handling is difficult. Maybe switch to textarea with
    # `\n` separator.
    def escape_locations_and_remove_ids
      [:location, :region].each do |key|
        next if @storable_params[:"#{key}_id"].blank?

        list = @storable_params[key].split("\n").map(&:strip)
        list = list.map { |location| "\"#{location.tr(",", "\\,")}\"" }
        @storable_params[key] = list.join(",")
        @storable_params.delete(:"#{key}_id")
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
