# frozen_string_literal: true

# Region autocompleter - queries Location records filtered to "region-sized"
# places (3-4 comma-separated parts = county/city level).
#
# Uses the same word-beginning matching as ForLocation for good typeahead UX,
# but filters to locations with 2-3 commas (3-4 parts like
# "Berkeley, Alameda Co., California, USA").
class Autocomplete::ForRegion < Autocomplete::ByWord
  # Minimum parts: 3 = county level ("Alameda Co., California, USA")
  # Maximum parts: 4 = city level ("Berkeley, Alameda Co., California, USA")
  MIN_COMMAS = 2
  MAX_COMMAS = 3

  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # Match word beginnings like ForLocation, but filter to region-sized places
  def rough_matches(letter)
    locations =
      Location.select(:name, :id, :north, :south, :east, :west).
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).
      where(comma_count_filter)

    matches_array(locations)
  end

  def exact_match(string)
    location = Location.select(:name, :id, :north, :south, :east, :west).
               where(Location[:name].eq(string)).
               where(comma_count_filter).first
    return [] unless location

    matches_array([location])
  end

  private

  # SQL filter for locations with MIN_COMMAS to MAX_COMMAS commas
  # (LENGTH(name) - LENGTH(REPLACE(name, ',', ''))) counts commas
  def comma_count_filter
    comma_count = "LENGTH(name) - LENGTH(REPLACE(name, ',', ''))"
    Arel.sql("(#{comma_count}) BETWEEN #{MIN_COMMAS} AND #{MAX_COMMAS}")
  end

  # Turn the instances into hashes, and alter name order if requested
  def matches_array(locations)
    matches = locations.map do |location|
      location = location.attributes.symbolize_keys
      location[:name] = Location.reverse_name(location[:name]) if reverse
      location
    end
    matches.sort_by! { |loc| [loc[:name], -loc[:id]] }
    matches.uniq { |loc| loc[:name] }
  end
end
