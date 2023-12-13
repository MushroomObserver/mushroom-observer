# frozen_string_literal: true

# rectangle on the surface of the earth, with borders: north, south, east, west
# used mostly (exclusively?) by model scopes
module Mappable
  class Box
    attr_reader :north, :south, :east, :west

    def initialize(north: nil, south: nil, east: nil, west: nil)
      @north = north
      @south = south
      @east = east
      @west = west
    end

    def valid?
      args_in_bounds? && south <= north
    end

    def straddles_180_deg?
      west > east
    end

    # Return a new box with edges expanded by delta
    # Useful for dealing with float rounding errors when
    # making comparisons to edges
    def expand(delta)
      Box.new(north: north + delta,
              south: south - delta,
              east: east + delta,
              west: west - delta)
    end

    ############################################################################

    private

    def args_in_bounds?
      south&.between?(-90, 90) && north&.between?(-90, 90) &&
        west&.between?(-180, 180) && east&.between?(-180, 180)
    end
  end
end
