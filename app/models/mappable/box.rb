# frozen_string_literal: true

# Non-AR model Box represents a geographic bounding box, a rectangle on the
# surface of the earth, with borders: north, south, east, west
# Used mostly by model scopes, and for area comparisons.
#
#  == Instance methods
#
#  valid?::              Return true if box is valid.
#  expand(delta_lat, delta_lng = nil)::  Return a new box with edges expanded
#                                        by delta (optional delta_lng)

module Mappable
  class Box
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Mappable::BoxMethods

    attribute :north, :float
    attribute :south, :float
    attribute :east, :float
    attribute :west, :float

    validates :north, presence: true, numericality: { in: -90..90 }
    validates :south, presence: true, numericality: { in: -90..90 }
    validates :east, presence: true, numericality: { in: -180..180 }
    validates :west, presence: true, numericality: { in: -180..180 }

    validate(:must_have_valid_bounds)

    def must_have_valid_bounds
      errors.add(:base, "Box must have valid boundaries.") unless south <= north
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
