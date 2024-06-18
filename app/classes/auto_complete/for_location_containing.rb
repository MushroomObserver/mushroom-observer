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
    matches =
      Location.contains(lat: lat, lng: lng).reject do |loc|
        location_box(loc).vague?
      end.sort_by! do |loc|
        location_box(loc).box_area
      end.pluck(:name)

    matches.map! { |m| Location.reverse_name(m) } if reverse
    matches.uniq
  end
  # rubocop:enable Style/MultilineBlockChain

  def location_box(loc)
    Mappable::Box.new(north: loc[:north], south: loc[:south],
                      east: loc[:east], west: loc[:west])
  end
end
