# frozen_string_literal: true

#
#  = PatternSearchable Concern
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

module PatternSearchable
  extend ActiveSupport::Concern

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
      @keywords = permitted_search_params.to_h.compact_blank #.reject do |_, v|
        # v == "0" || incomplete_date?(v)
      # end
      # format_date_params_into_strings
      concatenate_range_fields
      @sendable_params = substitute_ids_for_names(@keywords)
      # @storable_params = storable_params(@keywords)
    end

    # def incomplete_date?(value)
    #   value.is_a?(Hash) && value.values.any?(&:blank?)
    # end

    # Deal with date fields, which are stored as hashes with year, month, day.
    # Convert them to a single string. Can use `web_date` method on date fields.
    # def format_date_params_into_strings
    #   @keywords.each_key do |key|
    #     next unless fields_with_dates.include?(key.to_sym)
    #     next if @keywords[key][:year].blank?

    #     @keywords[key] = date_into_string(key)
    #     if @keywords[:"#{key}_range"].present?
    #       @keywords[:"#{key}_range"] = date_into_string(:"#{key}_range")
    #     end
    #   end
    # end

    # date is a hash with year, month, day. Convert to string.
    # def date_into_string(key)
    #   Date.new(*permitted_search_params.to_h[key].values.map(&:to_i)).web_date
    # end

    # Check for `fields_with_range`, and concatenate them if range val present,
    # removing the range field.
    def concatenate_range_fields
      @keywords.each_key do |key|
        next unless fields_with_range.include?(key.to_sym) &&
                    @keywords[:"#{key}_range"].present?

        @keywords[key] = [@keywords[key].strip,
                          @keywords[:"#{key}_range"].strip].join("-")
        @keywords.delete(:"#{key}_range")
      end
    end

    # SENDABLE_PARAMS
    # These methods don't modify the original @keywords hash.
    #
    # Controller declares `fields_with_ids` which autocompleter send ids.
    # This method substitutes the ids for the names.
    def substitute_ids_for_names(keywords)
      keywords.each_key do |key|
        next unless fields_with_ids.include?(key.to_sym) &&
                    keywords[:"#{key}_id"].present?

        keywords[key] = keywords[:"#{key}_id"]
        keywords.delete(:"#{key}_id")
      end
      keywords
    end

    # STORABLE_PARAMS
    # These methods don't modify the original @keywords hash.
    #
    # Store full strings for all values, including names and locations,
    # so we can repopulate the form with the same values.
    def storable_params(keywords)
      keywords = escape_names_and_remove_ids(keywords)
      escape_locations_and_remove_ids(keywords)
    end

    # Escape-quote the names, the way the short form requires.
    def escape_names_and_remove_ids(keywords)
      keywords.each_key do |key|
        next unless fields_with_ids.include?(key.to_sym) &&
                    keywords[:"#{key}_id"].present?

        list = keywords[key].split(",").map(&:strip)
        list = list.map { |name| "\"#{name}\"" }
        keywords[key] = list.join(",")
        keywords.delete(:"#{key}_id")
      end
      keywords
    end

    # Escape-quote the locations and their commas.
    def escape_locations_and_remove_ids(keywords)
      keywords.each_key do |key|
        next unless [:location, :region].include?(key.to_sym) &&
                    keywords[:"#{key}_id"].present?

        list = keywords[key].split(",").map(&:strip)
        list = list.map { |location| "\"#{location.tr(",", "\\,")}\"" }
        keywords[key] = list.join(",")
        keywords.delete(:"#{key}_id")
      end
      keywords
    end
  end
end
