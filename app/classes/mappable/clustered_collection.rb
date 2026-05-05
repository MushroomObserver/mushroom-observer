# frozen_string_literal: true

#
#  = Clustered Map Collection Class
#
#  Parallel to CollapsibleCollectionOfObjects but WITHOUT geographic
#  bucketing — one MapSet per source object. Used when the caller
#  wants the client to cluster dynamically via
#  @googlemaps/markerclusterer (issue #4159).
#
#  Exposes the same `sets` / `extents` / `representative_points`
#  attributes so the existing JS collection consumer doesn't have to
#  branch on payload shape.
#

module Mappable
  class ClusteredCollection
    attr_accessor :sets, :extents, :representative_points

    def initialize(sets)
      @sets = sets
      @extents = calc_extents
      @representative_points =
        [@extents.north_west, @extents.center, @extents.south_east]
    end

    def mapsets
      @sets.values
    end

    private

    def calc_extents
      result = Mappable::MapSet.new
      mapsets.each { |mapset| result.update_extents_with_box(mapset) }
      result
    end
  end
end
