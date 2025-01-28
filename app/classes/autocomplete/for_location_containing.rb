# frozen_string_literal: true

# Autocompleter for location names that encompass a given lat/lng.
class Autocomplete::ForLocationContaining < Autocomplete::ByWord
  attr_accessor :reverse, :lat, :lng

  # include Mappable::BoxMethods

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
    self.lat = params[:lat]
    self.lng = params[:lng]
  end

  # This list should be short. We don't care about matching a user input
  # letter, we're only matching locations that contain the given lat/lng.
  # rubocop:disable Style/MultilineBlockChain
  def rough_matches(_letter)
    locations =
      Location.select(:name, :id, :north, :south, :east, :west).
      contains_point(lat: lat.to_f, lng: lng.to_f).reject do |loc|
        location_box(loc).vague?
      end.sort_by! do |loc|
        location_box(loc).calculate_area
      end

    matches_array(locations)
  end
  # rubocop:enable Style/MultilineBlockChain

  def exact_match(_string)
    [rough_matches("").first]
  end

  # Turn the instances into hashes, and alter name order if requested
  def matches_array(locations)
    matches = locations.map do |location|
      location = location.attributes.symbolize_keys
      location[:name] = Location.reverse_name(location[:name]) if reverse
      location
    end
    # Don't re-sort, we want to keep the area order
    matches.uniq { |loc| loc[:name] }
    # matches.append({ name: " ", id: 0 }) # in case we need a blank row?
  end

  def location_box(loc)
    Mappable::Box.new(north: loc[:north], south: loc[:south],
                      east: loc[:east], west: loc[:west])
  end
end
