# frozen_string_literal: true

# Shared `sets` / `extents` / `representative_points` accessors plus
# the `mapsets` / `calc_extents` methods every Mappable collection
# class (ClusteredCollection, CollapsibleCollectionOfObjects) needs --
# both had accumulated byte-identical copies of these independently.
module Mappable
  module Collection
    def self.included(base)
      base.attr_accessor(:sets, :extents, :representative_points)
    end

    def mapsets
      @sets.values
    end

    def calc_extents
      result = Mappable::MapSet.new
      mapsets.each { |mapset| result.update_extents_with_box(mapset) }
      result
    end
  end
end
