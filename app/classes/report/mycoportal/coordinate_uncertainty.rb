# frozen_string_literal: true

require "haversine"

module Report
  class Mycoportal
    # Pure geometry for coordinateUncertaintyInMeters: farthest-corner
    # distance calculations given a location's bounding box and a
    # reference point (either the obscured/public lat-lng, or the box's
    # own center when no point is available).
    class CoordinateUncertainty
      def self.max_distance_to_any_corner(lat, lng, box)
        box_corners(box).map do |clat, clng|
          Haversine.distance(lat, lng, clat, clng).to_meters
        end.max.round
      end

      def self.distance_from_center_to_farthest_corner(box)
        center = box.center
        distance_to_farthest_corner(center.first, center.last, box)
      end

      def self.distance_to_farthest_corner(lat, lng, box)
        # east and west corners are equidistant from center because
        # boxes are isoceles trapezoids with bases parallel to the equator
        # farthest corner belongs to longest base
        if lat.positive?
          distance_to_se_corner(lat, lng, box)
        else
          distance_to_ne_corner(lat, lng, box)
        end
      end

      def self.distance_to_ne_corner(lat, lng, box)
        Haversine.distance(lat, lng, box.north, box.east).to_meters.round
      end

      def self.distance_to_se_corner(lat, lng, box)
        Haversine.distance(lat, lng, box.south, box.east).to_meters.round
      end

      def self.box_corners(box)
        [[box.north, box.east], [box.north, box.west],
         [box.south, box.east], [box.south, box.west]]
      end
    end
  end
end
