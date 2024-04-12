# frozen_string_literal: true

#  == Instance methods
#
#  location?::    Returns true.
#  observation?:: Returns false.
#  north_west::   Returns [north, west].
#  north_east::   Returns [north, east].
#  south_west::   Returns [south, west].
#  south_east::   Returns [south, east].
#  lat::          Returns center latitude.
#  lng::          Returns center longitude for MapSet.
#  center::       Returns center as [lat, long].
#  edges::        Returns [north, south, east, west].
#  north_south_distance:: Returns north - south.
#  east_west_distance::   Returns east - west (adjusting if straddles dateline).
#  box_area::             Returns the area described by a box, in kmˆ2.
#  vague?::       Arbitrary test for whether a box covers too large an area to
#                 be useful on a map.
#  delta_lat::    Returns north_south_distance * DELTA.
#  delta_lng::    Returns east_west_distance * DELTA.
#  lat_long_close?::  Determines if a given lat/long coordinate is within,
#                     or close to, a bounding box.
#  contains?(lat, lng)::  Does box contain the given latititude and longitude
#  contains_lat?
#  contains_long?

module Mappable
  module BoxMethods
    def location?
      true
    end

    def observation?
      false
    end

    # Return [north, west].
    def north_west
      [north, west]
    end

    # Return [north, east].
    def north_east
      [north, east]
    end

    # Return [south, west].
    def south_west
      [south, west]
    end

    # Return [south, east].
    def south_east
      [south, east]
    end

    # Return center latitude.
    def lat
      (north + south) / 2.0
    rescue StandardError
      nil
    end

    # Return center longitude for MapSet. (Google Maps takes `lng`, not `long`)
    def lng
      lng = (east + west) / 2.0
      if west > east && lng.negative?
        lng += 180
      elsif west > east && lng.positive?
        lng -= 180
      end
      lng
    rescue StandardError
      nil
    end

    # Return center as [lat, long].
    def center
      [lat, lng]
    end

    # Returns [north, south, east, west].
    def edges
      [north, south, east, west]
    end

    # Returns north - south.
    def north_south_distance
      north - south
    end

    # Returns east - west (adjusting if straddles dateline).
    def east_west_distance
      west <= east ? east - west : east - west + 360
    end

    def contains?(lat, lng)
      contains_lat?(lat) && contains_long?(lng)
    end

    def contains_lat?(lat)
      (south..north).cover?(lat)
    end

    def contains_long?(lng)
      return (west...east).cover?(lng) if west <= east

      (lng >= west) || (lng <= east)
    end

    # Returns the area described by a box, in kmˆ2.
    #   Formula for `the area of a patch of a sphere`:
    #     area = Rˆ2 * (long2 - long1) * (sin(lat2) - sin(lat1))
    #   where lat/lng in radians, R in km, Earth R rounded to 6372km
    def box_area
      6372 * 6372 * east_west_distance.to_radians *
        (Math.sin(north.to_radians) - Math.sin(south.to_radians)).abs
    end

    # Arbitrary test for whether a box covers too large an area to be useful on
    # a map with other boxes. Large boxes can obscure more precise locations.
    def vague?
      box_area > 24_000 # kmˆ2
    end

    # NOTE: DELTA = 0.20 is way too strict a limit for remote locations.
    # Larger delta makes more sense in remote areas, where the common-sense
    # postal address may be quite far from the observed GPS location.
    DELTA = 2.0

    def delta_lat
      north_south_distance * DELTA
    end

    def delta_lng
      east_west_distance * DELTA
    end

    # Determines if a given lat/long coordinate is within, or close to, a
    # bounding box. Method is used to decide if an obs lat/lng is "dubious"
    # with respect to the observation's assigned Location.
    def lat_long_close?(pt_lat, pt_lng)
      loc = Box.new(north: north, south: south, east: east, west: west)
      expanded = loc.expand(delta_lat, delta_lng)
      expanded.contains?(pt_lat, pt_lng)
    end
  end
end
