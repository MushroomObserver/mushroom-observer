# frozen_string_literal: true

# Autocompleter for location names that encompass a given lat/lng.
class AutoComplete::ForLocationContaining < AutoComplete::ByWord
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
      contains(lat: lat, lng: lng).reject do |loc|
        location_box(loc).vague?
      end.sort_by! do |loc|
        location_box(loc).box_area
      end

    # Turn the instances into hashes, and alter name order if requested
    matches = locations.map do |location|
      location = location.attributes.symbolize_keys
      location[:name] = Location.reverse_name(location[:name]) if reverse
      location
    end
    # Don't re-sort, we want to keep the area order
    matches.uniq { |loc| loc[:name] }
    # matches.append({ name: " ", id: 0 }) # in case we need a blank row?
  end
  # rubocop:enable Style/MultilineBlockChain

  def location_box(loc)
    Mappable::Box.new(north: loc[:north], south: loc[:south],
                      east: loc[:east], west: loc[:west])
  end
end
