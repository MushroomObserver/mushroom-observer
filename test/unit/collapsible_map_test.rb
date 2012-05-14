# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

require 'map_collapsible'
require 'map_set'

class CollapsibleMapTest < UnitTestCase

  def assert_mapset_is_point(mapset, lat, long)
    assert_true(mapset.is_point?)
    assert_false(mapset.is_box?)
    assert_in_delta(lat, mapset.lat, 0.0001)
    assert_in_delta(long, mapset.long, 0.0001)
    assert_in_delta(lat, mapset.north, 0.0001)
    assert_in_delta(lat, mapset.south, 0.0001)
    assert_in_delta(long, mapset.east, 0.0001)
    assert_in_delta(long, mapset.west, 0.0001)
    assert_in_delta(lat, mapset.center[0], 0.0001)
    assert_in_delta(long, mapset.center[1], 0.0001)
    assert_in_delta(lat, mapset.north_west[0], 0.0001)
    assert_in_delta(long, mapset.north_west[1], 0.0001)
    assert_in_delta(lat, mapset.north_east[0], 0.0001)
    assert_in_delta(long, mapset.north_east[1], 0.0001)
    assert_in_delta(lat, mapset.south_west[0], 0.0001)
    assert_in_delta(long, mapset.south_west[1], 0.0001)
    assert_in_delta(lat, mapset.south_east[0], 0.0001)
    assert_in_delta(long, mapset.south_east[1], 0.0001)
    assert_in_delta(0, mapset.north_south_distance, 0.0001)
    assert_in_delta(0, mapset.east_west_distance, 0.0001)
  end

  def assert_mapset_is_box(mapset, north, south, east, west)
    lat = (north + south) / 2
    long = (east + west) / 2
    assert_false(mapset.is_point?)
    assert_true(mapset.is_box?)
    assert_in_delta(lat, mapset.lat, 0.0001)
    assert_in_delta(long, mapset.long, 0.0001)
    assert_in_delta(north, mapset.north, 0.0001)
    assert_in_delta(south, mapset.south, 0.0001)
    assert_in_delta(east, mapset.east, 0.0001)
    assert_in_delta(west, mapset.west, 0.0001)
    assert_in_delta(lat, mapset.center[0], 0.0001)
    assert_in_delta(long, mapset.center[1], 0.0001)
    assert_in_delta(north, mapset.north_west[0], 0.0001)
    assert_in_delta(west, mapset.north_west[1], 0.0001)
    assert_in_delta(north, mapset.north_east[0], 0.0001)
    assert_in_delta(east, mapset.north_east[1], 0.0001)
    assert_in_delta(south, mapset.south_west[0], 0.0001)
    assert_in_delta(west, mapset.south_west[1], 0.0001)
    assert_in_delta(south, mapset.south_east[0], 0.0001)
    assert_in_delta(east, mapset.south_east[1], 0.0001)
    assert_in_delta(north - south, mapset.north_south_distance, 0.0001)
    assert_in_delta(east - west, mapset.east_west_distance, 0.0001)
  end

  def assert_mapset_is_box_straddling_dateline(mapset, north, south, east, west)
    lat = (north + south) / 2
    long = (east + west) / 2 + 180
    assert_false(mapset.is_point?)
    assert_true(mapset.is_box?)
    assert_in_delta(lat, mapset.lat, 0.0001)
    assert_in_delta(long, mapset.long, 0.0001)
    assert_in_delta(north, mapset.north, 0.0001)
    assert_in_delta(south, mapset.south, 0.0001)
    assert_in_delta(east, mapset.east, 0.0001)
    assert_in_delta(west, mapset.west, 0.0001)
    assert_in_delta(lat, mapset.center[0], 0.0001)
    assert_in_delta(long, mapset.center[1], 0.0001)
    assert_in_delta(north, mapset.north_west[0], 0.0001)
    assert_in_delta(west, mapset.north_west[1], 0.0001)
    assert_in_delta(north, mapset.north_east[0], 0.0001)
    assert_in_delta(east, mapset.north_east[1], 0.0001)
    assert_in_delta(south, mapset.south_west[0], 0.0001)
    assert_in_delta(west, mapset.south_west[1], 0.0001)
    assert_in_delta(south, mapset.south_east[0], 0.0001)
    assert_in_delta(east, mapset.south_east[1], 0.0001)
    assert_in_delta(north - south, mapset.north_south_distance, 0.0001)
    assert_in_delta(east - west + 360, mapset.east_west_distance, 0.0001)
  end

  def test_mapset_with_one_observation
    obs = observations(:unknown_with_lat_long)
    mapset = MapSet.new(obs)
    assert_obj_list_equal([obs], mapset.observations)
    assert_obj_list_equal([], mapset.locations)
    assert_obj_list_equal([obs.location], mapset.underlying_locations)
    assert_mapset_is_point(mapset, obs.lat, obs.long)
  end

  def test_mapset_with_one_location
    loc = locations(:albion)
    mapset = MapSet.new(loc)
    assert_obj_list_equal([], mapset.observations)
    assert_obj_list_equal([loc], mapset.locations)
    assert_obj_list_equal([loc], mapset.underlying_locations)
    assert_mapset_is_box(mapset, *loc.edges)
  end

  def test_extending_mapset_with_points
    obs = observations(:unknown_with_lat_long)
    lat1, long1 = obs.lat, obs.long
    mapset = MapSet.new(obs)

    # Make sure this doesn't change anything first.
    mapset.update_extents_with_point(obs)
    assert_mapset_is_point(mapset, lat1, long1)

    # Now this should expand it into a small box.
    lat2 = obs.lat += 0.2
    long2 = obs.long += 0.4
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, lat2, lat1, long2, long1)

    # This is contained inside the box, so should do nothing.
    obs.lat -= 0.1
    obs.long -= 0.2
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, lat2, lat1, long2, long1)

    # Now extend southern edge.
    lat3 = obs.lat -= 0.5
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, lat2, lat3, long2, long1)

    # Now extend western edge all the way across the dateline(!)
    # long3 = obs.long = 170
    # mapset.update_extents_with_point(obs)
    # assert_mapset_is_box_straddling_dateline(mapset, lat2, lat3, long2, long3)
  end

  def test_extending_mapset_with_boxes
    obs = observations(:amateur_observation)
    loc = locations(:burbank)
    n, s, e, w = *loc.edges
    mapset = MapSet.new(obs)
    assert_mapset_is_point(mapset, obs.lat, obs.long)

    # Observation is contained inside Burbank.
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Make sure this doesn't change anything.
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box contained entirely inside.
    loc.north -= 0.0001
    loc.south += 0.0001
    loc.east -= 0.0001
    loc.west += 0.0001
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box totally surrounding.
    n = loc.north = n + 0.1
    s = loc.south = s - 0.1
    e = loc.east = e + 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting northwest corner.
    n = loc.north = n + 0.1
        loc.south = s + 0.1
        loc.east = e - 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting northeast corner.
    n = loc.north = n + 0.1
        loc.south = s + 0.1
    e = loc.east = e + 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting southwest corner.
        loc.north = n - 0.1
    s = loc.south = s - 0.1
        loc.east = e - 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting southeast corner.
        loc.north = n - 0.1
    s = loc.south = s - 0.1
    e = loc.east = e + 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting northern edge.
    n = loc.north = n + 0.1
        loc.south = s + 0.1
        loc.east = e - 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting southern edge.
        loc.north = n - 0.1
    s = loc.south = s - 0.1
        loc.east = e - 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting eastern edge.
        loc.north = n - 0.1
        loc.south = s + 0.1
    e = loc.east = e + 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box intersecting western edge.
        loc.north = n - 0.1
        loc.south = s + 0.1
        loc.east = e - 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box covering northern half.
    n = loc.north = n + 0.1
        loc.south = s + 0.1
    e = loc.east = e + 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box covering southern half.
        loc.north = n - 0.1
    s = loc.south = s - 0.1
    e = loc.east = e + 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box covering eastern half.
    n = loc.north = n + 0.1
    s = loc.south = s - 0.1
    e = loc.east = e + 0.1
        loc.west = w + 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Add box covering western half.
    n = loc.north = n + 0.1
    s = loc.south = s - 0.1
        loc.east = e - 0.1
    w = loc.west = w - 0.1
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Now extend eastern edge over the dateline(!)
    # loc.north = 81
    # loc.south = 80
    # loc.east = -170
    # loc.west = 170
    # mapset.update_extents_with_box(loc)
    # assert_mapset_is_box_straddling_dateline(mapset, 81, s, -170, w)
  end

  def test_mapping_one_observation
    obs = observations(:amateur_observation)
    coll = CollapsibleCollectionOfMappableObjects.new(obs)
    # need to test coll.extents... but not sure what it should be to start with!
    assert_equal(1, coll.mapsets.length)
    mapset = coll.mapsets.first
    assert_true(mapset.is_point?)
    assert_false(mapset.is_box?)
    assert_equal(obs.lat, mapset.lat)
    assert_equal(obs.long, mapset.long)
    assert_equal(obs.lat, mapset.north)
    assert_equal(obs.lat, mapset.south)
    assert_equal(obs.long, mapset.east)
    assert_equal(obs.long, mapset.west)
    assert_obj_list_equal([obs], mapset.observations)
    assert_obj_list_equal([], mapset.locations)
    assert_obj_list_equal([], mapset.underlying_locations)
  end

  def test_mapping_one_location
    loc = locations(:albion)
    coll = CollapsibleCollectionOfMappableObjects.new(loc)
    # need to test coll.extents... but not sure what it should be to start with!
    assert_equal(1, coll.mapsets.length)
    mapset = coll.mapsets.first
    assert_false(mapset.is_point?)
    assert_true(mapset.is_box?)
    assert_equal((loc.north+loc.south)/2, mapset.lat)
    assert_equal((loc.east+loc.west)/2, mapset.long)
    assert_equal(loc.north, mapset.north)
    assert_equal(loc.south, mapset.south)
    assert_equal(loc.east, mapset.east)
    assert_equal(loc.west, mapset.west)
    assert_obj_list_equal([], mapset.observations)
    assert_obj_list_equal([loc], mapset.locations)
    assert_obj_list_equal([loc], mapset.underlying_locations)
  end
end
