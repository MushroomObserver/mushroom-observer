# frozen_string_literal: true

# This requires Stimulus delaying the fetch until we have a complete word.
class AutoComplete::ForRegion < AutoComplete::ByWord
  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  def rough_matches(words)
    words = Location.reverse_name(words) if reverse
    matches = Observation.in_region(words).pluck(:where, :location_id)

    matches.map! { |m, _id| Location.reverse_name(m) } if reverse
    matches.reject { |m| m[1].nil? }.sort_by(&:first).uniq(&:first)
  end
end
