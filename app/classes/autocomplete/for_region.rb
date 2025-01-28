# frozen_string_literal: true

# This requires Stimulus delaying the fetch until we have a complete word.
class Autocomplete::ForRegion < Autocomplete::ByWord
  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # Using observation.where gives the possibility of strings with no ID.
  # Trying to match "region" means matching the end of the postal format string.
  # "scientific" format users will have the country first, so reverse words
  def rough_matches(words)
    words = Location.reverse_name(words) if reverse
    regions = Observation.in_region(words).select(:where, :location_id)

    matches_array(regions)
  end

  # Doesn't make sense to have an exact match for a region.
  # def exact_match(words)
  #   words = Location.reverse_name(words) if reverse
  #   region = Observation.in_region(words).select(:where, :location_id).first
  #   return [] unless region

  #   matches_array([region])
  # end

  # Turn the instances into hashes, and alter name order if requested
  # Also change the names of the hash keys.
  def matches_array(regions)
    matches = regions.map do |region|
      region = region.attributes.symbolize_keys
      format = reverse ? Location.reverse_name(region[:where]) : region[:where]
      { name: format, id: region[:location_id] || 0 }
    end
    # Sort by name and prefer those with a non-zero ID
    matches.sort_by! { |reg| [reg[:name], -reg[:id]] }
    matches.uniq { |reg| reg[:name] }
  end
end
