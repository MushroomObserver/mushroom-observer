# encoding: utf-8
#
#  = Collapsible Map Collection Class
#
#  This class takes a bunch of mappable objects and collapses them into a more
#  manageable number of points and boxes.  Resulting points and boxes each may
#  contain one or more Observation's and Location's.
#
#  Note: Uses the global +MAX_MAP_OBJECTS+ to limit the number of objects.
#
#  == Typical Usage
#
#    collection = CollapsibleCollectionOfMappableObjects.new(query.results)
#    gmap.center_on_points(*collection.representative_points)
#    for mapset in collection.mapsets
#      draw_mapset(gmap, mapset)
#    end
#
################################################################################

class CollapsibleCollectionOfMappableObjects
  def initialize(objects)
    init_sets(objects)
    group_objects_into_sets
  end

  def mapsets
    @sets.values
  end

  def extents
    @extents ||= calc_extents
  end

  def representative_points
    [extents.north_west, extents.center, extents.south_east]
  end

private

  MAX_PRECISION = 4
  MIN_PRECISION = -1
  
  def init_sets(objects)
    objects = [objects] if !objects.is_a?(Array)
    raise "Tried to create empty map!" if objects.empty?
    @sets = {}
    for obj in objects
      if obj.is_a?(Location)
        add_box_set(obj, [obj], MAX_PRECISION)
      elsif obj.is_a?(Observation)
        if obj.lat and !obj.lat_long_dubious?
          add_point_set(obj, [obj], MAX_PRECISION)
        elsif loc = obj.location
          add_box_set(loc, [obj], MAX_PRECISION)
        end
      else
        raise "Tried to map #{obj.class}!"
      end
    end
  end

  def group_objects_into_sets
    prec = MAX_PRECISION - 1
    while @sets.length > max_objects
      old_sets = @sets.values
      @sets = {}
      for set in old_sets
        add_box_set(set, set.objects, prec)
      end
      prec -= 1
    end
  end

  # need to be able to override this in test suite
  def max_objects
    MAX_MAP_OBJECTS
  end

  def add_point_set(loc, objs, prec)
    x, y = round_loc_to_precision(loc, prec)
    set = @sets["#{x} #{y} 0 0"] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_point(loc)
  end

  def add_box_set(loc, objs, prec)
    x, y = round_loc_to_precision(loc, prec)
    h = loc.north_south_distance.round(prec)
    w = loc.east_west_distance.round(prec)
    set = @sets["#{x} #{y} #{w} #{h}"] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_box(loc)
  end

  def round_loc_to_precision(loc, prec)
    if prec >= MIN_PRECISION
      y = loc.lat.round(prec)
      x = loc.long.round(prec)
    else
      y = loc.lat >= 45 ? 90 : loc.lat <= -45 ? 90 : 0
      x = loc.long >= 150 || loc.long <= -150 ? 180 : loc.long.round(-2)
    end
    return x, y
  end
  
  def calc_extents
    result = MapSet.new
    for mapset in mapsets
      result.update_extents_with_box(mapset)
    end
    return result
  end
end
