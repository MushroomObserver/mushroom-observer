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

  def initialize(objects = [])
    @objects = objects.is_a?(Array) ? objects : [objects]
    @north = @south = @east = @west = nil
    init_objects
  end

  def init_objects
    for obj in @objects
      if obj.is_location?
        update_extents_with_box(obj)
      elsif obj.is_observation?
        if obj.lat && !obj.lat_long_dubious?
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
    @objects.select(&:is_observation?)
  end

  def locations
    @objects.select(&:is_location?)
  end

  def underlying_locations
    @objects.map do |obj|
      if obj.is_location?
        obj
      elsif obj.is_observation? && obj.location
        obj.location
      end
    end.reject(&:nil?).uniq
  end

  def is_point?
    (north - south) < 0.0001
  end

  def is_box?
    (north - south) >= 0.0001
  end

  def north_west
    [north, west]
  end

  def north_east
    [north, east]
  end

  def south_west
    [south, west]
  end

  def south_east
    [south, east]
  end

  def lat
    ((north + south) / 2.0).round(4)
  end

  def long
    long = ((east + west) / 2.0).round(4)
    long += 180 if @west > @east
    long
  end

  def center
    [lat, long]
  end

  def edges
    [north, south, east, west]
  end

  def north_south_distance
    north - south
  end

  def east_west_distance
    west > east ? east - west + 360 : east - west
  end

  def update_extents_with_point(loc)
    lat = loc.lat.to_f.round(4)
    long = loc.long.to_f.round(4)
    if !@north
      @north = @south = lat
      @east = @west = long
    else
      @north = lat if lat > @north
      @south = lat if lat < @south
      # point not contained within existing extents
      if @east >= @west ? (long > @east || long < @west) : (long > @east && long < @west)
        east_dist = long > @east ? long - @east : long - @east + 360
        west_dist = long < @west ? @west - long : @west - long + 360
        if east_dist <= west_dist
          @east = long
        else
          @west = long
        end
      end
    end
  end

  def update_extents_with_box(loc)
    n = loc.north.to_f.round(4)
    s = loc.south.to_f.round(4)
    e = loc.east.to_f.round(4)
    w = loc.west.to_f.round(4)
    if !@north
      @north = n
      @south = s
      @east = e
      @west = w
    else
      @north = n if n > @north
      @south = s if s < @south
      # new box not completely contained within old box
      if @east >= @west ? (e < w || w < @west || e > @east) : (e >= w || w < @west || e > @east)
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
    end
  end
end
