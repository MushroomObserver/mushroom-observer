# frozen_string_literal: true

#
#  = Searchable Concern
#
#  This is a module of reusable methods included by controllers that handle
#  "faceted" query searches per model, with separate inputs for each keyword.
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

module Searchable
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

      @sendable_params = remove_ids_and_format_strings(@keywords)
      # @storable_params = configure_storable_params(@keywords)
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

    # SENDABLE_PARAMS - params with ids can be sent to index and query.
    #
    # This method deletes the strings typed in the form and sends ids, saving a
    # lookup at the receiver. However, we still want a legible string saved in
    # the session, so we can repopulate the form with legible values - plus
    # maybe in the url. Could send the id versions as separate `filter` param?
    #
    # Need to modify autocompleters to check for record id on load if prefilled.
    def substitute_strings_with_ids(keywords)
      search_subclass.fields_with_ids.each do |key|
        next if keywords[:"#{key}_id"].blank?

        keywords[key] = keywords[:"#{key}_id"]
        keywords.delete(:"#{key}_id")
      end
      keywords
    end

    # STORABLE_PARAMS - params for the pattern string in session.
    # These methods don't modify the original @keywords.
    #
    # Ideally we'd store full strings for all values, including names and
    # locations, so we can repopulate the form with the same values.
    def remove_ids_and_format_strings(keywords)
      escape_strings_and_remove_ids(keywords)
      escape_locations_and_remove_ids(keywords)
    end

    # Escape-quote the strings, the way the short form requires.
    # rubocop:disable Metrics/AbcSize
    def escape_strings_and_remove_ids(keywords)
      search_subclass.fields_with_ids.each do |key|
        # location, region handled separately
        next if keywords[key].blank? || strings_with_commas.include?(key.to_sym)

        list = keywords[key].split(",").map(&:strip)
        list = list.map { |name| "\"#{name}\"" }
        keywords[key] = list.join(",")
        next if keywords[:"#{key}_id"].blank?

        keywords.delete(:"#{key}_id")
      end
      keywords
    end
    # rubocop:enable Metrics/AbcSize

    # Escape-quote the locations and their commas. We'd prefer to have legible
    # strings in the url, but the comma handling is difficult.
    def escape_locations_and_remove_ids(keywords)
      if keywords[:location].present?
        list = keywords[:location].split("\n").map(&:strip)
        list = list.map { |location| escape_location_string(location) }
        keywords[:location] = list.join(",")
      end
      keywords.delete(:location_id) if keywords[:location_id].present?
      escape_region_string(keywords)
    end

    def escape_region_string(keywords)
      return keywords if keywords[:region].blank?

      keywords[:region] = escape_location_string(keywords[:region].strip)
      keywords
    end

    def escape_location_string(location)
      "\"#{location.tr(",", "\\,")}\""
    end

    def strings_with_commas
      [:location, :region].freeze
    end
  end
  # rubocop:enable Metrics/BlockLength
end
