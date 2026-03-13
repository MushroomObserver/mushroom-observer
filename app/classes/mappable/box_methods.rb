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
#  straddles_180_deg?::   Returns true if box straddles 180 degrees.
#  calculate_area::       Returns the area described by a box, in kmˆ2.
#  vague?::       Arbitrary test for whether a box covers too large an area to
#                 be useful on a map.
#  delta_lat::    Returns north_south_distance * DELTA.
#  delta_lng::    Returns east_west_distance * DELTA.
#  lat_lng_close?::  Determines if a given lat/long coordinate is within,
#                     or close to, a bounding box.
#  contains?(lat, lng)::  Does box contain the given latititude and longitude
#  contains_lat?
#  contains_lng?

module Mappable
  module BoxMethods
    def self.included(base)
      base.extend(ClassMethods)
    end

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
    def calculate_lat
      (north + south) / 2.0
    rescue StandardError
      nil
    end

    # Return center longitude for MapSet. (Google Maps takes `lng`, not `long`)
    def calculate_lng
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

    # Return center as [lat, lng].
    def center
      [calculate_lat, calculate_lng]
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

    def straddles_180_deg?
      west > east
    end

    def contains?(lat, lng)
      contains_lat?(lat) && contains_lng?(lng)
    end

    def contains_lat?(lat)
      (south..north).cover?(lat)
    end

    def contains_lng?(lng)
      return (west..east).cover?(lng) unless straddles_180_deg?

      (lng >= west) || (lng <= east)
    end

    # Returns the area described by a box, in kmˆ2.
    #   Formula for `the area of a patch of a sphere`:
    #     area = Rˆ2 * (long2 - long1) * (sin(lat2) - sin(lat1))
    #   where lat/lng in radians, R in km, Earth R rounded to 6372km
    def calculate_area
      6372 * 6372 * east_west_distance.to_radians *
        (Math.sin(north.to_radians) - Math.sin(south.to_radians)).abs
    end

    # Arbitrary test for whether a box covers too large an area to be useful on
    # a map with other boxes. Large boxes can obscure more precise locations.
    def vague?
      calculate_area > MO.obs_location_max_area
    end

    # NOTE: DELTA = 0.20 is way too strict a limit for remote locations.
    # Larger delta makes more sense in remote areas, where the common-sense
    # postal address may be quite far from the observed GPS location.
    DELTA = 2.0

    def delta_lat(delta = DELTA)
      @delta_lat ||= north_south_distance.abs * delta
    end

    def delta_lng(delta = DELTA)
      @delta_lng ||= east_west_distance.abs * delta
    end

    # Determines if a given lat/long coordinate is within, or close to, a
    # bounding box. Method is used to decide if an obs lat/lng is "dubious"
    # with respect to the observation's assigned Location.
    def lat_lng_close?(pt_lat, pt_lng)
      loc = Box.new(north: north, south: south, east: east, west: west)
      expanded = loc.expand(DELTA)
      expanded.contains?(pt_lat, pt_lng)
    end

    # These (or Arel equivalents) are necessary for update_all to be efficient.
    # Used in update_box_area_and_center_columns to populate or restore columns.
    module ClassMethods
      def update_center_and_area_sql
        "center_lat = #{lat_sql}, center_lng = #{lng_sql}, " \
        "box_area = #{area_sql}"
      end

      def lat_sql
        "(north + south) / 2"
      end

      def lng_sql
        "CASE WHEN ((west > east) AND (east + west < 0)) " \
        "THEN (((east + west) / 2) + 180) " \
        "WHEN ((west > east) AND (east + west > 0)) " \
        "THEN (((east + west) / 2) - 180) " \
        "ELSE ((east + west) / 2) END"
      end

      def area_sql
        "6372 * 6372 * " \
        "RADIANS(CASE WHEN (west <= east) THEN (east - west) " \
        "ELSE (east - west + 360) END) * " \
        "ABS(SIN(RADIANS(north)) - SIN(RADIANS(south)))"
      end
    end
  end
end
