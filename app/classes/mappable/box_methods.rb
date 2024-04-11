# frozen_string_literal: true

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
      lng += 180 if west > east
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

    # Returns the area described by a box, in kmˆ2.
    #   Formula for `the area of a patch of a sphere`:
    #     area = Rˆ2 * (long2 - long1) * (sin(lat2) - sin(lat1))
    #   where lat/lng in radians, R in km, Earth R rounded to 6372km
    def geometric_area
      6372 * 6372 * east_west_distance.to_radians *
        (Math.sin(north.to_radians) - Math.sin(south.to_radians)).abs
    end

    # Arbitrary test for whether a box covers too large an area to be useful on
    # a map with other boxes. Large boxes can obscure more precise locations.
    def vague?
      geometric_area > 24_000 # kmˆ2
    end

    # Determines if a given lat/long coordinate is within, or close to, a
    # bounding box. Method is used to decide if an obs lat/lng is "dubious"
    # with respect to the observation's assigned Location.
    # NOTE: delta = 0.20 is way too strict a limit for remote locations.
    # Larger delta makes more sense in remote areas, where the common-sense
    # postal address may be quite far from the observed GPS location.
    def lat_long_close?(lat, long)
      delta = 2.0
      delta_lat = north_south_distance * delta
      delta_long = east_west_distance * delta
      return false if lat > north + delta_lat
      return false if lat < south - delta_lat

      if west <= east
        return false if long > east + delta_long
        return false if long < west - delta_long
      elsif long < west + delta_long && long > east - delta_long
        return false
      end
      true
    end
  end
end
