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
      return if at_least_one_val_nonzero? && north_south_makes_sense?

      errors.add(:base, "Box must have valid boundaries.")
    end

    # Return a new box with edges expanded by delta multiplier applied to each
    # dimension. Useful for dealing with float rounding errors when
    # making comparisons to edges.
    def expand(delta = DELTA)
      Box.new(north: north + delta_lat(delta),
              south: south - delta_lat(delta),
              east: rectify(east + delta_lng(delta)),
              west: rectify(west - delta_lng(delta)))
    end

    ############################################################################

    private

    # to_i converts nil values to zero
    def at_least_one_val_nonzero?
      !(south.to_i.zero? && north.to_i.zero? &&
        west.to_i.zero? && east.to_i.zero?)
    end

    def north_south_makes_sense?
      south && north && south <= north
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
