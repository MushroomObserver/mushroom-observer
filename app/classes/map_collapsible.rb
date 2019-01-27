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
#  == Typical Usage
#
#    collection = CollapsibleCollectionOfMappableObjects.new(query.results)
#    gmap.center_on_points(*collection.representative_points)
#    for mapset in collection.mapsets
#      draw_mapset(gmap, mapset)
#    end
#
###############################################################################

class CollapsibleCollectionOfMappableObjects
  def initialize(objects, max_objects = MO.max_map_objects)
    @max_objects = max_objects
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

  # Algorithm, such as it is, works by rounding to fewer and fewer places, each
  # time combining points and boxes which are the same.  In the end, it rounds
  # to nearest 90°, so it is guaranteed(?) to reach the target minimum number
  # of objects.
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

  def init_sets(objects)
    objects = [objects] unless objects.is_a?(Array)
    fail "Tried to create empty map!" if objects.empty?

    @sets = {}
    for obj in objects
      if obj.is_location?
        add_box_set(obj, [obj], MAX_PRECISION)
      elsif obj.is_observation?
        if obj.lat && !obj.lat_long_dubious?
          add_point_set(obj, [obj], MAX_PRECISION)
        elsif loc = obj.location
          add_box_set(loc, [obj], MAX_PRECISION)
        end
      else
        fail "Tried to map #{obj.class}!"
      end
    end
  end

  def group_objects_into_sets
    prec = next_precision(MAX_PRECISION)
    while @sets.length > @max_objects && prec >= MIN_PRECISION
      old_sets = @sets.values
      @sets = {}
      for set in old_sets
        add_box_set(set, set.objects, prec)
      end
      prec = next_precision(prec)
    end
  end

  def add_point_set(loc, objs, prec)
    x, y = round_lat_long_to_precision(loc, prec)
    set = @sets[[x, y, 0, 0]] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_point(loc)
  end

  def add_box_set(loc, objs, prec)
    x, y = round_lat_long_to_precision(loc, prec)
    h = round_number(loc.north_south_distance, prec)
    w = round_number(loc.east_west_distance, prec)
    set = @sets[[x, y, w, h]] ||= MapSet.new
    set.add_objects(objs)
    set.update_extents_with_box(loc)
  end

  def round_lat_long_to_precision(loc, prec)
    if prec > MIN_PRECISION
      return [round_number(loc.lat, prec), round_number(loc.long, prec)]
    end

    [loc.lat >= 45 ? 90 : loc.lat <= -45 ? -90 : 0,
     loc.long >= 150 || loc.long <= -150 ? 180 : round_number(loc.long, prec)]
  end

  def calc_extents
    result = MapSet.new
    for mapset in mapsets
      result.update_extents_with_box(mapset)
    end
    result
  end
end
