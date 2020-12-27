# frozen_string_literal: true

# Return array of suggested Locations for a given user input (name or lat/lon)
class Location < AbstractModel
  # SQL string to calculate db grid size in lat/lon squares
  # This is the db counterpart of pseudoarea, differing by rounding error
  GRID_SQUARES = "IF(east >= west, east - west, 360 + east - west) " \
                 "* (north - south)"

  # max suggested size in lat/lon "squares"
  # suggestions should not include a Location with a larger pseudoarea
  MAX_SUGGESTED_SIZE = 6800

  # class methods
  class << self
    # Return some locations that are close to the given name and/or geolocation
    # data from google and/or lat/long provided by user.
    def suggestions(str, geolocation)
      return suggestions_for_country(str, geolocation) if dubious_country?(str)
      return suggestions_for_state(str, geolocation) if dubious_state?(str)

      suggestions_for_the_rest(str)
    end

    # Turn geolocation structure into an MO location name (might not exist).
    def geolocation_to_name(geolocation)
      geo_country = geolocation[:country]
      geo_state = geolocation[:state]
      geo_county = geolocation[:county].to_s.sub(/County$/, "Co.")
      geo_city = geolocation[:city]
      [geo_city, geo_county, geo_state, geo_country].reject(&:blank?).join(", ")
    end

    # Locations with enough verbal levels of precision
    # containing the given lat/lon, excluding Locations that are "too large"
    # sorted by size, ascending
    def suggestions_for_latlong(lat, long)
      all = Location.where("(south <= ? AND north >= ?) AND " \
                           "IF(east >= west, west <= ? AND east >= ?, " \
                           "west <= ? OR east >= ?)",
                           lat, lat, long, long, long, long).
            # exclude locations that are too large
            where("#{GRID_SQUARES} <= #{MAX_SUGGESTED_SIZE}").
            to_a
      # Return only most "precise" Locations.
      [3, 2, 1, 0].each do |n|
        locs = all.select { |loc| loc.name.split(",").length > n }
        return locs.sort_by(&:pseudoarea) if locs.any?
      end
      []
    end

    # Return suggested locations if country is unrecognized.
    def suggestions_for_country(str, geolocation)
      terms = str.split(",").map(&:strip)
      given_country = terms.last
      suggestions = \
        suggestions_if_country_is_state(given_country, terms) ||
        suggestions_if_geo_country_good(str, geolocation) ||
        suggestions_if_country_misspelled(given_country, geolocation[:country])
      if suggestions.first.is_a?(Location)
        suggestions
      else
        suggestions_for_alt_countries(suggestions, terms, geolocation)
      end
    end

    # Is "country" actually a recognized state?
    def suggestions_if_country_is_state(given_country, terms)
      alt_countries = countries_with_state(given_country)
      return unless alt_countries.any?

      terms.push("") # move terms to left to make room for country
      alt_countries
    end

    # Did google provide the name of a country we recognize?
    def suggestions_if_geo_country_good(str, geolocation)
      return unless (geo_country = geolocation[:country])
      return unless Location.understood_country?(geo_country)

      # Just see if maybe the user omitted the country...
      suggestions = suggestions_for_state("#{str}, #{geo_country}", geolocation)
      suggestions.any? ? suggestions : [geo_country]
    end

    # Find closest matches to the country names the user and google provided.
    def suggestions_if_country_misspelled(given_country, geo_country)
      similar_countries(given_country) | similar_countries(geo_country)
    end

    # Mash together any suggestions for any of the suggested alternative
    # countries we put together above.
    def suggestions_for_alt_countries(alt_countries, terms, geolocation)
      alt_countries.map do |alt_country|
        terms[-1] = alt_country
        alt_str = terms.join(", ")
        if dubious_state?(alt_str)
          suggestions_for_state(alt_str, geolocation)
        else
          suggestions_for_the_rest(alt_str)
        end
      end.flatten.uniq
    end

    # Return suggested locations if state is unrecognized (but country is).
    def suggestions_for_state(str, geolocation)
      terms = str.split(",").map(&:strip)
      given_country = terms.pop
      # There's nothing we can really do if we don't have the list of states
      # for this country, so just treat it like a normal string. This method
      # is all about taking advantage of knowing the set of available states.
      good_states = understood_states(given_country)
      return suggestions_with_tail(terms, [given_country]) if good_states.empty?

      given_state = unabbreviate_state(terms.pop, given_country)
      geo_state = geolocation[:state]
      suggestions = \
        suggestions_if_given_state_is_good(given_state, given_country) ||
        suggestions_if_geo_state_is_good(geo_state, terms, given_state,
                                         given_country) ||
        suggestions_if_state_misspelled(given_state, geo_state, given_country)
      if suggestions.first.is_a?(Location)
        suggestions
      else
        suggestions_for_alt_states(suggestions, terms, given_country)
      end
    end

    # List of "suggestions" is trivial if the given (unabbreviated) state
    # is already known to be good.
    def suggestions_if_given_state_is_good(given_state, given_country)
      return unless understood_states(given_country).member?(given_state)

      [given_state]
    end

    # Did google provide the name of a state we recognize?
    def suggestions_if_geo_state_is_good(geo_state, terms, given_state,
                                         given_country)
      return unless understood_states(given_country).member?(geo_state)

      # Just see if maybe the user omitted the state...
      alt_str = (terms + [given_state, geo_state, given_country]).join(", ")
      suggestions = suggestions_for_the_rest(alt_str)
      suggestions.any? ? suggestions : [geo_state]
    end

    # Find closest matches to the state names the user and google provided.
    def suggestions_if_state_misspelled(given_state, geo_state, given_country)
      similar_states(given_state, given_country) |
        similar_states(geo_state, given_country)
    end

    # Mash together any suggestions for any of the suggested alternative
    # states we put together above.
    def suggestions_for_alt_states(alt_states, terms, given_country)
      alt_states.map do |alt_state|
        suggestions_with_tail(terms, [alt_state, given_country]) |
          suggestions_without_county(terms, [alt_state, given_country])
      end.flatten.uniq
    end

    # Return suggested locations if both country and state recognized.
    def suggestions_for_the_rest(str)
      head_terms = str.split(",").map(&:strip)
      given_country = head_terms.pop
      given_state = head_terms.pop
      tail_terms = [given_state, given_country]
      suggestions_with_tail(head_terms, tail_terms) |
        suggestions_without_county(head_terms, tail_terms)
    end

    # Return locations which are close except lack county (or have it wrong).
    def suggestions_without_county(head_terms, tail_terms)
      return [] if head_terms.length < 2 ||
                   !head_terms.last.match?(/ Co(\.|unty)$/)

      suggestions_with_tail(head_terms[0..-2], tail_terms)
    end

    # Return locations which match at the end and are close near the front.
    def suggestions_with_tail(head_terms, tail_terms)
      head = head_terms.join(", ")
      tail = tail_terms.join(", ")
      return Location.where(name: tail) if head.blank?

      str = "#{head}, #{tail}"
      terms = head_terms + tail_terms
      r = levenshtein_threshold(head, head)
      Location.where("name LIKE ? AND LENGTH(name) > ?",
                     "%, #{tail}", str.length - r).
        select { |loc| hybrid_match?(terms, loc.name.split(", ")) }
    end

    # ----------------------------
    #  Helpers
    # ----------------------------

    private

    # Compare two partial locations that have been split into component terms.
    # Allow any but the first term to be missing entirely from first operand.
    # All terms that are present must be at least close (using Levenshtein
    # distance to allow for some variation in spelling).
    def hybrid_match?(terms1, terms2)
      return false if terms1.empty? || terms2.length < terms1.length

      i = 0
      skips = terms2.length - terms1.length # num of terms2 allowed to skip
      terms2.each do |term2|
        if fuzzy_match?(terms1[i], term2)
          i += 1
        elsif i > 0 && skips > 0 # rubocop:disable Style/NumericPredicate
          skips -= 1
        else
          return false
        end
      end
      true
    end

    # Check if two strings are similar.
    def fuzzy_match?(word1, word2)
      return false if word1.blank? || word2.blank?

      r = levenshtein_threshold(word1, word2)
      Levenshtein.distance(word1, word2) <= r
    end

    # How many edits for a word to still be "close"?
    #   10 chars = 2 edits
    #   15 chars = 3 edits
    #   20 chars = 4 edits
    #   etc.
    def levenshtein_threshold(str1, str2)
      [((str1.length + str2.length) * 0.1).to_i, 2].max
    end

    def similar_countries(str)
      return [] if str.blank?

      understood_countries.select { |x| Levenshtein.distance(str, x) <= 2 }
    end

    def similar_states(str, given_country)
      return [] if str.blank?

      abbrevs = STATE_ABBREVIATIONS[given_country]
      return [abbrevs[str]] if abbrevs && abbrevs[str]

      understood_states(given_country).select do |x|
        Levenshtein.distance(str, x) <= 2
      end
    end

    def countries_with_state(str)
      understood_countries.select do |alt_country|
        abbrevs = STATE_ABBREVIATIONS[alt_country]
        str2 = abbrevs && abbrevs[str] || str
        understood_states(alt_country)&.member?(str2)
      end
    end

    def dubious_state?(name)
      given_country = country(name) or return
      given_state = state(name) or return
      if has_known_states?(given_country)
        !understood_state?(given_state, given_country)
      else
        !state_in_database?(given_state, given_country)
      end
    end

    def state_in_database?(given_state, given_country)
      part_name = "#{given_state}, #{given_country}"
      Location.where("name = ? OR name LIKE ?",
                     part_name, "%, #{part_name}").any?
    end
  end
end
