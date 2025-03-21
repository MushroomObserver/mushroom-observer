# frozen_string_literal: true

# Nimmo note: Is it desirable to make `rough_matches` a scope for these models?
# Doing that, plus a method to pluck the values, would solve the ABC violation.
# Any caching advantage in that? Then below, it'd be something like:
#   Observation.rough_matches(letter).pluck_matches
# Or would this scatter the code?
# Thinking the scope could be useful, or it could use this class.
#
class Autocomplete::ForLocation < Autocomplete::ByWord
  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # We're no longer matching undefined observation.where strings.
  def rough_matches(letter)
    locations =
      Location.select(:name, :id, :north, :south, :east, :west).
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%")))

    matches_array(locations)
  end

  def exact_match(string)
    location = Location.select(:name, :id, :north, :south, :east, :west).
               where(Location[:name].eq(string)).first
    return [] unless location

    matches_array([location])
  end

  # Turn the instances into hashes, and alter name order if requested
  def matches_array(locations)
    matches = locations.map do |location|
      location = location.attributes.symbolize_keys
      location[:name] = Location.reverse_name(location[:name]) if reverse
      location
    end
    # Sort by name and prefer those with a non-zero ID
    matches.sort_by! { |loc| [loc[:name], -loc[:id]] }
    # matches.uniq { |loc| loc[:name] }
  end
end
