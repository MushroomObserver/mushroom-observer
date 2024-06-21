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

  def rough_matches(letter)
    matches =
      Observation.select(:where).distinct.
      where(Observation[:where].matches("#{letter}%").
        or(Observation[:where].matches("% #{letter}%"))).
      pluck(:where, :location_id) +
      Location.select(:name).distinct.
      where(Location[:name].matches("#{letter}%").
        or(Location[:name].matches("% #{letter}%"))).pluck(:name, :id)

    matches.map! { |m, id| [Location.reverse_name(m), id] } if reverse
    # matches without id are strings only. give id: 0, and sort by unique name
    matches.map { |m, id| [m, id.nil? ? 0 : id] }.sort_by(&:first).uniq(&:first)
  end
end
