# encoding: utf-8
#
#  = Collapsible Map Collection Class
#
#  This class takes a bunch of mappable objects and collapses them into a more
#  manageable number of points and boxes.  Resulting points and boxes each may
#  contain one or more Observation's and Location's.
#
#  == Typical Usage
#
#    collection = CollapsibleCollectionOfMappableObjects.new(query.results)
#    gmap.center_on_points(*collection.extents)
#    for mapset in collection.mapsets
#      draw_mapset(gmap, mapset)
#    end
#
################################################################################

class CollapsibleCollectionOfMappableObjects
  MAX_OBJECTS = 200

  def initialize(objects)
    init_sets(objects)
    group_objects_into_sets
  end

  def mapsets
    @sets.values
  end

  def extents
    @sets.values.map(&:north_west) +
    @sets.values.map(&:south_east)
  end

private
  def init_sets(objects)
    objects = [objects] if !objects.is_a?(Array)
    raise "Tried to create empty map!" if objects.empty?
    @sets = {}
    for obj in objects
      if obj.is_a?(Location)
        add_box_set(obj, [obj], 4)
      elsif obj.is_a?(Observation)
        if obj.lat and !obj.lat_long_dubious?
          add_point_set(obj, [obj], 4)
        elsif loc = obj.location
          add_box_set(loc, [obj], 4)
        end
      else
        raise "Tried to map #{obj.class}!"
      end
    end
  end

  def group_objects_into_sets
    prec = 3
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
    MAX_OBJECTS
  end

  def add_point_set(loc, objs, prec)
    y = loc.lat.round(prec)
    x = loc.long.round(prec)
    set = @sets["#{x} #{y} 0 0"] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_point(loc)
  end

  def add_box_set(loc, objs, prec)
    y = loc.lat.round(prec)
    x = loc.long.round(prec)
    h = loc.north_south_distance.round(prec)
    w = loc.east_west_distance.round(prec)
    set = @sets["#{x} #{y} #{w} #{h}"] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_box(loc)
  end
end
