# frozen_string_literal: true

# Box represents a geographic bounding box, a rectangle on the surface of the
# earth, with borders: north, south, east, west
# Used mostly by model scopes, and for area comparisons.
#
#  == Instance methods
#
#  valid?::              Return true if box is valid.
#  straddles_180_deg?::  Return true if box straddles 180 degrees.
#  expand(delta_lat, delta_lng = nil)::  Return a new box with edges expanded
#                                        by delta (optional delta_lng)

module Mappable
  class Box
    attr_reader :north, :south, :east, :west

    def initialize(north: nil, south: nil, east: nil, west: nil)
      @north = north
      @south = south
      @east = east
      @west = west
    end

    include Mappable::BoxMethods

    def valid?
      args_in_bounds? && south <= north
    end

    def straddles_180_deg?
      west > east
    end

    # Return a new box with edges expanded by delta (optional delta_lng)
    # Useful for dealing with float rounding errors when
    # making comparisons to edges.
    def expand(delta_lat, delta_lng = nil)
      delta_lng ||= delta_lat

      Box.new(north: north + delta_lat,
              south: south - delta_lat,
              east: rectify(east + delta_lng),
              west: rectify(west - delta_lng))
    end

    ############################################################################

    private

    def args_in_bounds?
      south&.between?(-90, 90) && north&.between?(-90, 90) &&
        west&.between?(-180, 180) && east&.between?(-180, 180)
    end

    # Return a valid longitude between -180 and 180, for `expand` method
    def rectify(lng)
      if lng < -180
        lng + 360
      elsif lng > 180
        lng - 360
      else
        lng
      end
    end
  end
end
