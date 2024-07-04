# frozen_string_literal: true

# Nimmo note: Is it desirable to make `rough_matches` a scope for these models?
# Doing that, plus a method to pluck the values, would solve the ABC violation.
# Any caching advantage in that? Then below, it'd be something like:
#   Observation.rough_matches(letter).pluck_matches
# Or would this scatter the code?
# Thinking the scope could be useful for graphQL, or it could use this class.
#
class AutoComplete::ForLocation < AutoComplete::ByWord
  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # We're no longer matching undefined observation.where strings.
  def rough_matches(letter)
    locations =
      Location.select(:name, :north, :south, :east, :west).
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).
      pluck(:name, :id, :north, :south, :east, :west)

    # rubocop:disable Metrics/ParameterLists
    locations.map! do |name, id, north, south, east, west|
      format = reverse ? Location.reverse_name(name) : name
      { name: format, id:, north:, south:, east:, west: }
    end
    # rubocop:enable Metrics/ParameterLists
    # Sort by name and prefer those with a non-zero ID
    locations.sort_by! { |loc| [loc[:name], -loc[:id]] }
    locations.uniq { |loc| loc[:name] }
  end
end
