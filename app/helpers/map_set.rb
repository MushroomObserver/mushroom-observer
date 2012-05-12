# encoding: utf-8
#
#  = Map Set Class
#
#  This class is used to hold a set of mappable objects, and provide the
#  information needed to map these as a single point or box. 
#
#  == Typical Usage
#
#    mapset = MapSet.new(observations_at_one_location)
#    num_obs = mapset.observations.length
#    num_loc = mapset.locations.length
#    if mapset.is_point?
#      draw_marker(mapset.center)
#    else
#      draw_box(mapset.north_west, mapset.north_east, ..., mapset.north_west)
#    end
#
################################################################################

class MapSet
  attr_reader :objects, :north, :south, :east, :west

  def initialize(objects=[])
    objects = [objects] if !objects.is_a?(Array)
    @objects = objects
    @north = @south = @east = @west = nil
    init_objects
  end

  def init_objects
    for obj in @objects
      if obj.is_a?(Location)
        update_extents_with_box(obj)
      elsif obj.is_a?(Observation)
        if obj.lat and !obj.lat_long_dubious?
          update_extents_with_point(obj)
        elsif loc = obj.location
          update_extents_with_box(loc)
        end
      else
        raise "Tried to map #{obj.class}!"
      end
    end
  end

  # NOTE: does not update extents!
  def add_objects(objects)
    @objects += objects
  end

  def observations
    @objects.select {|x| x.is_a? Observation}
  end

  def locations
    @objects.select {|x| x.is_a? Location}
  end

  def underlying_locations
    @objects.map do |obj|
      if obj.is_a?(Location)
        obj
      elsif obj.is_a?(Observation) and obj.location
        obj.location
      else
        nil
      end
    end.reject(&:nil?).uniq
  end

  def is_point?
    (north - south) < 0.0001
  end

  def is_box?
    (north - south) >= 0.0001
  end

  def north_west; [north, west]; end
  def north_east; [north, east]; end
  def south_west; [south, west]; end
  def south_east; [south, east]; end

  def lat
    (north + south) / 2
  end

  def long
    long = (east + west) / 2
    long += 180 if @west > @east
    return long
  end

  def center
    [lat, long]
  end

  def north_south_distance
    north - south
  end

  def east_west_distance
    west > east ? east - west + 360 : east - west
  end

  def update_extents_with_point(loc)
    lat, long = loc.lat, loc.long
    if !@north
      @north = @south = lat
      @east = @west = long
    else
      @north = lat if lat > @north
      @south = lat if lat < @south
      if @east >= @west
        @east = long if long > @east
        @west = long if long < @west
      else
        @east = long if long < @east
        @west = long if long > @west
      end
    end
  end

  def update_extents_with_box(loc)
    n, s, e, w = loc.north, loc.south, loc.east, loc.west
    if !@north
      @north = n
      @south = s
      @east = e
      @west = w
    else
      @north = n if n > @north
      @south = s if s < @south
      if @east >= @west
        @east = e if e > @east
        @west = w if w < @west
      else
        @east = e if e < @east
        @west = w if w > @west
      end
    end
  end
end
