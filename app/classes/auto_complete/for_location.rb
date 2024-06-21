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

  # Using observation.where gives the possibility of strings with no ID.
  def rough_matches(letter)
    locations =
      Observation.select(:where).distinct.
      where(Observation[:where].matches("#{letter}%").
        or(Observation[:where].matches("% #{letter}%"))).
      pluck(:where, :location_id) +
      Location.select(:name).distinct.
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).pluck(:name, :id)

    # matches without id are "where" strings only.
    # give them an id: 0, and sort by unique name
    locations.map! do |loc, id|
      format = reverse ? Location.reverse_name(loc) : loc
      { name: format, id: id.nil? ? 0 : id }
    end
    # Sort by name and prefer those with a non-zero ID
    locations.sort_by! { |loc| [loc[:name], -loc[:id]] }
    locations.uniq { |loc| loc[:name] }
  end
end
