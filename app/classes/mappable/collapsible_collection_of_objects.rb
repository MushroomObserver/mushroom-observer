# frozen_string_literal: true

#
#  = Collapsible Map Collection Class
#
#  This class takes a bunch of mappable objects and collapses them
#  into a more manageable number of points and boxes.  Resulting
#  points and boxes each may contain one or more Observation's and
#  Location's.
#
#  Note: Uses the global +MO.max_map_objects+ to limit the number of
#  objects.
#
#  Uses the following other classes:
#   MapSet
#   Mappable::MinimalObservation or Mappable::MinimalLocation
#   Location (or other ActiveRecord object)
#
#  Object has this shape:
# <Mappable::CollapsibleCollectionOfObjects{
#   max_objects: 100,
#   sets: {
#     [x, y, w, h] => <Mappable::MapSet{
#       east:
#       north:
#       south:
#       west:
#       objects: [
#         <Mappable::MinimalObservation{
#           id:
#           lat:
#           lng:
#           location_id:
#           location: (ActiveRecord)
#         }>
#       ]
#     }>
#   }
# }>
#
#  == Typical Usage
#
#    collection = Mappable::CollapsibleCollectionOfObjects.new(query.results)
#
###############################################################################

module Mappable
  class CollapsibleCollectionOfObjects
    attr_accessor :sets, :extents, :representative_points

    def initialize(objects, max_objects = MO.max_map_objects)
      @max_objects = max_objects
      init_sets(objects)
      group_objects_into_sets
      init_derived_attributes
    end

    def mapsets
      @sets.values
    end

    def init_derived_attributes
      @extents = calc_extents
      @representative_points =
        [@extents.north_west, @extents.center, @extents.south_east]
    end

    private

    # Algorithm, such as it is, works by rounding to fewer and fewer places,
    # each time combining points and boxes which are the same.  In the end, it
    # rounds to nearest 90°, so it is guaranteed(?) to reach the target minimum
    # number of objects.
    PRECISION = [
      10_000,
      5000,
      2000,
      1000,
      500,
      200,
      100,
      50,
      20,
      10,
      5,
      2,
      1,
      1.0 / 2,
      1.0 / 5,
      1.0 / 10,
      1.0 / 20,
      1.0 / 50,
      1.0 / 90
    ].freeze
    MAX_PRECISION = PRECISION.first
    MIN_PRECISION = PRECISION.last

    def next_precision(prec)
      PRECISION[PRECISION.index(prec) + 1] || 0
    end

    def round_number(num, prec)
      (num.to_f * prec).round.to_f / prec
    end

    # Dismiss any obj that has an unknown location. Also dismiss objects with
    # vague locations (e.g. "Nova Scotia") if mapping a collection of objects.
    # (Mapsets containing unknown or vague locations will obscure useful points
    # if specific locations get grouped with huge nonspecific areas.)
    def mappable_location?(is_collection, loc)
      return true unless is_collection

      !loc&.vague? && !Location.is_unknown?(loc&.name)
    end

    # Similar to MapSet.init_objects_and_derive_extents
    # Objects may be observations, or Mappable::MinimalLocations/Observations,
    # whose properties are different. Names::MapsController#show sends obs.
    #
    # For single observations, this always returns points if we have lat/lng...
    # ignores "dubiousness" when the point disagrees with location.
    #
    # For maps of multiple observations, it returns only sets of location boxes.
    # Even though points are noticeable at any zoom, they may get collapsed with
    # other nearby points into tiny boxes, becoming undetectable on the map.
    def init_sets(objects)
      objects = [objects] unless objects.is_a?(Array)
      raise("Tried to create empty map!") if objects.empty?

      @sets = {}
      is_collection = objects.count > 1
      will_be_grouped = objects.count > @max_objects
      objects.each do |obj|
        loc = obj.location? ? obj : obj.location
        mappable = mappable_location?(is_collection, loc)
        if obj.location? && mappable
          add_box_set(loc, [obj], MAX_PRECISION)
        elsif obj.observation?
          if (!will_be_grouped || !loc) && obj.lat # && !obj.lat_lng_dubious?
            add_point_set(obj, [obj], MAX_PRECISION)
          elsif loc && mappable
            add_box_set(loc, [obj], MAX_PRECISION)
          end
        elsif mappable
          # Only raise an error if it was otherwise mappable
          # We do want to ignore non-mappable locations.
          raise("Tried to map #{obj.class} #{obj.id}.")
        end
      end
      # Give the sets an initial sort by north value, before grouping.
      @sets = @sets.sort_by { |_key, value| value.north }.reverse.to_h
    end

    def group_objects_into_sets
      prec = next_precision(MAX_PRECISION)
      while @sets.length > @max_objects && prec >= MIN_PRECISION
        old_sets = @sets.values
        @sets = {}
        old_sets.each do |set|
          add_box_set(set, set.objects, prec)
        end
        prec = next_precision(prec)
      end
    end

    def add_point_set(loc_or_obs, objs, prec)
      x, y = round_lat_lng_to_precision(loc_or_obs, prec)
      set = @sets[[x, y, 0, 0]] ||= Mappable::MapSet.new
      set.add_objects(objs)
      set.update_extents_with_point(loc_or_obs)
    end

    def add_box_set(loc, objs, prec)
      x, y = round_lat_lng_to_precision(loc, prec)
      h = round_number(loc.north_south_distance, prec)
      w = round_number(loc.east_west_distance, prec)
      set = @sets[[x, y, w, h]] ||= Mappable::MapSet.new
      set.add_objects(objs)
      set.update_extents_with_box(loc)
    end

    # loc may be an observation, MinimalObservation or a set (with lng)
    def round_lat_lng_to_precision(loc, prec)
      if prec > MIN_PRECISION
        return [round_number(loc.lat, prec), round_number(loc.lng, prec)]
      end

      [if loc.lat >= 45
         90
       else
         loc.lat <= -45 ? -90 : 0
       end,
       loc.lng >= 150 || loc.lng <= -150 ? 180 : round_number(loc.lng, prec)]
    end

    def calc_extents
      result = Mappable::MapSet.new
      mapsets.each do |mapset|
        result.update_extents_with_box(mapset)
      end
      result
    end
  end
end
