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

  # We don't care about matching a user input letter, this list should be short
  # rubocop:disable Style/MultilineBlockChain
  def rough_matches(_letter)
    locations =
      Location.select(:name, :north, :south, :east, :west).
      contains(lat: lat, lng: lng).reject do |loc|
        location_box(loc).vague?
      end.sort_by! do |loc|
        location_box(loc).box_area
      end.pluck(:name, :id, :north, :south, :east, :west)

    # rubocop:disable Metrics/ParameterLists
    locations.map! do |name, id, north, south, east, west|
      format = reverse ? Location.reverse_name(name) : name
      { name: format, id:, north:, south:, east:, west: }
    end
    # rubocop:enable Metrics/ParameterLists
    # Don't re-sort, we want to keep the area order
    locations.uniq { |loc| loc[:name] }
  end
  # rubocop:enable Style/MultilineBlockChain

  def location_box(loc)
    Mappable::Box.new(north: loc[:north], south: loc[:south],
                      east: loc[:east], west: loc[:west])
  end
end
