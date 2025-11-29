# frozen_string_literal: true

# Region autocompleter - queries Location records filtered to "region-sized"
# places (1-4 comma-separated parts = country through sub-county level).
#
# Uses the same word-beginning matching as ForLocation for good typeahead UX,
# but filters to locations with 0-3 commas (1-4 parts like
# "Bolivia" through "Perigord, Dordogne, Nouvelle-Aquitaine, France").
class Autocomplete::ForRegion < Autocomplete::ByWord
  # Minimum parts: 1 = country level ("Bolivia")
  # Maximum parts: 4 = sub-county ("Perigord, Dordogne, ...")
  MIN_COMMAS = 0
  MAX_COMMAS = 3

  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # Match word beginnings like ForLocation, but filter to region-sized places
  # Order by box_area descending so broader regions appear first
  def rough_matches(letter)
    locations =
      Location.select(:name, :id, :north, :south, :east, :west, :box_area).
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).
      where(comma_count_filter).
      order(box_area: :desc)

    matches_array(locations)
  end

  def exact_match(string)
    location =
      Location.select(:name, :id, :north, :south, :east, :west, :box_area).
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
  # Preserves box_area DESC order from query (bigger regions first)
  def matches_array(locations)
    matches = locations.map do |location|
      location = location.attributes.symbolize_keys
      location[:name] = Location.reverse_name(location[:name]) if reverse
      location
    end
    # Don't re-sort - preserve box_area order from query
    matches.uniq { |loc| loc[:name] }
  end
end
