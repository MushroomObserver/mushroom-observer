# frozen_string_literal: true

#
#  = Map Set Class
#
#  This class is used to hold a set of mappable objects, and provide the
#  information needed to map these as a single point or box.
#
#  == Typical Usage
#
#    mapset = Mappable::MapSet.new(observations_at_one_location)
#    num_obs = mapset.observations.length
#    num_loc = mapset.locations.length
#    if mapset.is_point
#      draw_marker(mapset.center)
#    else
#      draw_box(mapset.north_west, mapset.north_east, ..., mapset.north_west)
#    end
#
#  AN 20231109
#  To avoid duplicating instance methods like `south_east`, `is_box` that will
#  be used in the stimulus controller that composes markers, i'm storing all
#  the derived values on the object too. They're called the same way in Ruby,
#  but when the object is sent `to_json` it will have all the values encoded.
#  The title and caption are accessors, so they can be set in the map helper.
#  The objects are an accessor, because they get stripped before sending to JS.
#
module Mappable
  class MapSet
    attr_reader :north, :south, :east, :west, :is_point, :is_box,
                :north_east, :south_east, :south_west, :north_west, :lat, :long,
                :north_south_distance, :east_west_distance, :center, :edges
    attr_accessor :objects, :title, :caption

    def initialize(objects = [])
      @objects = objects.is_a?(Array) ? objects : [objects]
      @north = @south = @east = @west = nil
      init_objects_and_derive_extents
      init_derived_attributes
    end

    def init_objects_and_derive_extents
      @objects.each do |obj|
        if obj.is_location?
          update_extents_with_box(obj)
        elsif obj.is_observation?
          if obj.lat && !obj.lat_long_dubious?
            update_extents_with_point(obj)
          elsif (loc = obj.location)
            update_extents_with_box(loc)
          end
        else
          raise("Tried to map #{obj.class}!")
        end
      end
    end

    # NOTE: does not update extents!
    def add_objects(objects)
      @objects += objects
    end

    def observations
      @objects.select(&:is_observation?)
    end

    def locations
      @objects.select(&:is_location?)
    end

    def underlying_locations
      @objects.filter_map do |obj|
        if obj.is_location?
          obj
        elsif obj.is_observation? && obj.location
          obj.location
        end
      end.uniq
    end

    def init_derived_attributes
      @is_point = (@north - @south) < 0.0001
      @is_box = (@north - @south) >= 0.0001
      @north_west = [@north, @west]
      @north_east = [@north, @east]
      @south_west = [@south, @west]
      @south_east = [@south, @east]
      @lat = ((@north + @south) / 2.0).round(4)
      @long = ((@east + @west) / 2.0).round(4)
      @long += 180 if @west > @east
      @center = [@lat, @long]
      @edges = [@north, @south, @east, @west]
      @north_south_distance = @north - @south
      @east_west_distance = @west > @east ? @east - @west + 360 : @east - @west
    end

    def update_extents_with_point(loc)
      lat = loc.lat.to_f.round(4)
      long = loc.long.to_f.round(4)
      if @north
        @north = lat if lat > @north
        @south = lat if lat < @south
        if long_outside_existing_extents?(long)
          east_dist = long > @east ? long - @east : long - @east + 360
          west_dist = long < @west ? @west - long : @west - long + 360
          if east_dist <= west_dist
            @east = long
          else
            @west = long
          end
        end
      else
        @north = @south = lat
        @east = @west = long
      end
    end

    def long_outside_existing_extents?(long)
      if @east >= @west
        long > @east || long < @west
      else
        long > @east && long < @west
      end
    end

    def update_extents_with_box(loc)
      n = loc.north.to_f.round(4)
      s = loc.south.to_f.round(4)
      e = loc.east.to_f.round(4)
      w = loc.west.to_f.round(4)
      if @north
        @north = n if n > @north
        @south = s if s < @south
        if new_box_not_contained_by_old_box?(e, w)
          # overlap, neither or both straddle dateline
          if (@east >= @west && e >= w && w <= @east && e >= @west) ||
            (@east < @west && e < w)
            @east = e if e > @east
            @west = w if w < @west
          # overlap, old straddles dateline
          elsif @east < @west && e >= w && (w <= @east || e >= @west)
            @east = e if e > @east && w < @east
            @west = w if w < @west && e > @west
          # overlap, new straddles dateline
          elsif @east >= @west && e < w && (w <= @east || e >= @west)
            @east = e if e > @east || w < @east
            @west = w if w < @west || e > @west
          # no overlap
          else
            east_dist = w > @east ? w - @east : w - @east + 360
            west_dist = e < @west ? @west - e : @west - e + 360
            if east_dist < west_dist
              @east = e
            else
              @west = w
            end
          end
        end
      else
        @north = n
        @south = s
        @east = e
        @west = w
      end
    end

    def new_box_not_contained_by_old_box?(east, west)
      if @east >= @west
        east < west || west < @west || east > @east
      else
        east >= west || west < @west || east > @east
      end
    end
  end
end
