require "test_helper"

require "map_collapsible"
require "map_set"

class BigDecimal
  # Make this class dump out easier-to-read diagnostics when tests fail.
  def inspect
    str = format("%f", self)
    str.sub(/0+$/, ""). # remove trailing zeros
      sub(/\.$/, "")
  end
end

class CollapsibleMapTest < UnitTestCase
  def assert_mapset_is_point(mapset, lat, long)
    assert_true(mapset.is_point?)
    assert_false(mapset.is_box?)
    assert_mapset(mapset, lat, long, lat, lat, long, long, 0, 0)
  end

  def assert_mapset_is_box(mapset, north, south, east, west)
    lat = (north + south) / 2.0
    long = (east + west) / 2.0
    assert_false(mapset.is_point?)
    assert_true(mapset.is_box?)
    if east >= west
      assert_mapset(mapset, lat, long,
                    north, south, east, west, north - south, east - west)
    else
      assert_mapset(mapset, lat, long + 180,
                    north, south, east, west, north - south, east - west + 360)
    end
  end

  def assert_mapset(mapset, lat, long,
                    north, south, east, west, north_south, east_west)
    assert_extents(mapset, north, south, east, west)
    assert_in_delta(lat, mapset.lat, 0.0001,
                    "expect <#{lat.round(4)}>, actual <#{mapset.lat.round(4)}>")
    assert_in_delta(long, mapset.long, 0.0001)
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
    assert_in_delta(north_south, mapset.north_south_distance, 0.0001)
    assert_in_delta(east_west, mapset.east_west_distance, 0.0001)
  end

  def assert_extents(mapset, north, south, east, west)
    errors = []
    errors << "north" if north.round(4) != mapset.north.round(4)
    errors << "south" if south.round(4) != mapset.south.round(4)
    errors << "east" if east.round(4) != mapset.east.round(4)
    errors << "west" if west.round(4) != mapset.west.round(4)
    return unless errors.any?

    expect = format("N=%.4f S=%.4f E=%.4f W=%.4f", north, south, east, west)
    actual = format("N=%.4f S=%.4f E=%.4f W=%.4f",
                    mapset.north, mapset.south, mapset.east, mapset.west)
    message = "Extents wrong: <#{errors.join(", ")}>\n"\
              "Expect: <#{expect}>\n"\
              "Actual: <#{actual}>"
    flunk(message)
  end

  def assert_list_of_mapsets(coll, objs)
    list = objs.reject(&:nil?).map do |x|
      x.length == 2 ? [x[0], x[0], x[1], x[1]] : x
    end

    format_string = "%9.4f %9.4f %9.4f %9.4f"
    expect = list.map { |x| format(format_string, *x) }.sort
    actual = coll.mapsets.map(&:edges).map do |x|
      format(format_string, *x)
    end.sort

    messages = []
    differ = false
    (0..[expect.length, actual.length].max).each do |i|
      message = format("%39.39s    %39.39s", expect[i], actual[i])
      if expect[i] != actual[i]
        differ = true
        message += " (*)"
      end
      messages << message
    end
    assert_not differ, "Mapsets are wrong: expect -vs- actual\n" \
                   "#{messages.join} \n"
  end

  # ------------------------------------------------------------

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
    n = s = obs.lat
    e = w = obs.long
    mapset = MapSet.new(obs)

    # Make sure this doesn't change anything first.
    mapset.update_extents_with_point(obs)
    assert_mapset_is_point(mapset, n, w)

    # Extend northern edge.
    n = obs.lat = n + 0.2
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Extend eastern edge
    e = obs.long = e + 0.2
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Extend southern edge.
    s = obs.lat = s - 0.2
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    # Extend western edge.
    w = obs.long = w - 0.2
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    # This is inside, so does nothing.
    obs.lat = (n + s) / 2.0
    obs.long = (e + w) / 2.0
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)
  end

  def test_extending_mapset_with_boxes
    obs = observations(:amateur_obs)
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
  end

  def test_extending_mapset_with_points_over_dateline
    obs = Observation.new
    n = s = obs.lat = 45
    e = w = obs.long = -170
    mapset = MapSet.new(obs)
    assert_mapset_is_point(mapset, n, w)

    n = obs.lat = 50
    w = obs.long = 170
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    obs.lat = 48
    w = obs.long = 10
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    obs.lat = 48
    w = obs.long = -10
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)

    obs.lat = 48
    e = obs.long = -160
    mapset.update_extents_with_point(obs)
    assert_mapset_is_box(mapset, n, s, e, w)
  end

  # rubocop:disable Metrics/LineLength
  def test_extending_mapset_with_boxes_over_dateline
    # Neither old nor new box straddling dateline:
    do_box_extension_test(-170, -150, 150, 170, 150, -150)   # | ▀▀▀▀▀       ▄▄▄▄▄ |
    do_box_extension_test(-50, -10, 10, 50, -50, 50)         # |    ▀▀▀▀▀ ▄▄▄▄▄    |
    do_box_extension_test(-30, 10, -10, 30, -30, 30)         # |      ▀▀███▄▄      |
    do_box_extension_test(-10, 10, -20, 20, -20, 20)         # |       ▄███▄       |
    do_box_extension_test(-20, 20, -10, 10, -20, 20)         # |       ▀███▀       |
    do_box_extension_test(-10, 30, -30, 10, -30, 30)         # |      ▄▄███▀▀      |
    do_box_extension_test(10, 50, -50, -10, -50, 50)         # |    ▄▄▄▄▄ ▀▀▀▀▀    |
    do_box_extension_test(150, 170, -170, -150, 150, -150)   # | ▄▄▄▄▄       ▀▀▀▀▀ |

    # New straddling dateline, but not old:
    do_box_extension_test(-170, -160, 150, -150, 150, -150)  # |▄█▄             ▄▄▄|
    do_box_extension_test(-170, -120, 150, -150, 150, -120)  # |▄██▀▀           ▄▄▄|
    do_box_extension_test(-140, -100, 150, -150, 150, -100)  # |▄▄▄ ▀▀▀▀        ▄▄▄|
    do_box_extension_test(100, 140, 150, -150, 100, -150)    # |▄▄▄        ▀▀▀▀ ▄▄▄|
    do_box_extension_test(120, 170, 150, -150, 120, -150)    # |▄▄▄           ▀▀██▄|
    do_box_extension_test(160, 170, 150, -150, 150, -150)    # |▄▄▄             ▄█▄|

    # Old straddling dateline, but not new:
    do_box_extension_test(170, -170, 80, 90, 80, -170)       # |▀█▀             ▀▀▀|
    do_box_extension_test(165, -170, 160, 170, 160, -170)    # |▀██▄▄           ▀▀▀|
    do_box_extension_test(150, -170, 160, 170, 150, -170)    # |▀▀▀ ▄▄▄▄        ▀▀▀|
    do_box_extension_test(170, -170, -80, -70, 170, -70)     # |▀▀▀        ▄▄▄▄ ▀▀▀|
    do_box_extension_test(170, -165, -170, -160, 170, -160)  # |▀▀▀           ▄▄██▀|
    do_box_extension_test(170, -150, -170, -160, 170, -150)  # |▀▀▀             ▀█▀|

    # Both straddling dateline:
    do_box_extension_test(150, -170, 170, -150, 150, -150)   # |██▄             ▀██|
    do_box_extension_test(170, -170, 150, -150, 150, -150)   # |██▄             ▄██|
    do_box_extension_test(150, -150, 170, -170, 150, -150)   # |██▀             ▀██|
    do_box_extension_test(170, -150, 150, -170, 150, -150)   # |██▀             ▄██|
  end
  # rubocop:enable Metrics/LineLength

  def do_box_extension_test(west1, east1, west2, east2, west3, east3)
    loc = Location.new
    loc.north = 50
    loc.south = 40
    loc.east = east1
    loc.west = west1
    mapset = MapSet.new(loc)
    loc.east = east2
    loc.west = west2
    mapset.update_extents_with_box(loc)
    assert_mapset_is_box(mapset, 50, 40, east3, west3)
  end

  def test_mapping_one_observation_with_gps
    obs = observations(:amateur_obs)
    assert(obs.lat && obs.long && !obs.location)
    coll = CollapsibleCollectionOfMappableObjects.new(obs)
    assert_equal(1, coll.mapsets.length)
    mapset = coll.mapsets.first
    assert_mapset_is_point(mapset, obs.lat, obs.long)
    assert_extents(coll.extents, obs.lat, obs.lat, obs.long, obs.long)
    assert_obj_list_equal([obs], mapset.observations)
    assert_obj_list_equal([], mapset.locations)
    assert_obj_list_equal([], mapset.underlying_locations)
  end

  def test_mapping_one_observation_with_location
    obs = observations(:minimal_unknown_obs)
    assert(!obs.lat && !obs.long && obs.location)
    coll = CollapsibleCollectionOfMappableObjects.new(obs)
    assert_equal(1, coll.mapsets.length)
    mapset = coll.mapsets.first
    assert_mapset_is_box(mapset, *obs.location.edges)
    assert_extents(coll.extents, *obs.location.edges)
    assert_obj_list_equal([obs], mapset.observations)
    assert_obj_list_equal([], mapset.locations)
    assert_obj_list_equal([obs.location], mapset.underlying_locations)
  end

  def test_mapping_one_location
    loc = locations(:albion)
    coll = CollapsibleCollectionOfMappableObjects.new(loc)
    assert_equal(1, coll.mapsets.length)
    mapset = coll.mapsets.first
    assert_mapset_is_box(mapset, *loc.edges)
    assert_extents(coll.extents, *loc.edges)
    assert_obj_list_equal([], mapset.observations)
    assert_obj_list_equal([loc], mapset.locations)
    assert_obj_list_equal([loc], mapset.underlying_locations)
  end

  def test_mapping_a_bunch_of_points
    data = [
      [10, 10],       # 0 --._____
      [10.1, 10.1],   # 1 --'     \
      [20, 10],       # 2 ---------}-.
      [20, 20],       # 3 -----.__/  |
      [22, 22],       # 4 -----'     |_
      [0, 0],         # 5 -----------|
      [-10, 10],      # 6 -----._____|
      [-12, 12],      # 7 -----'
      [-90, 50],      # 8 -------------
      [-70, -30]      # 9 -------------
    ]
    observations = data.map do |lat, long|
      Observation.new(lat: lat, long: long)
    end

    coll = CollapsibleCollectionOfMappableObjects.new(observations,
                                                      observations.length)
    assert_list_of_mapsets(coll, data)

    data[0] = [10.1, 10.0, 10.1, 10.0]
    data[1] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 9)
    assert_list_of_mapsets(coll, data)

    data[3] = [22, 20, 22, 20]
    data[6] = [-10, -12, 12, 10]
    data[4] = data[7] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 8)
    assert_list_of_mapsets(coll, data)
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 7)
    assert_list_of_mapsets(coll, data)

    data[0] = [22, 10, 22, 10]
    data[2] = data[3] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 6)
    assert_list_of_mapsets(coll, data)
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 5)
    assert_list_of_mapsets(coll, data)

    data[0] = [22, -12, 22, 0]
    data[5] = data[6] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 4)
    assert_list_of_mapsets(coll, data)
  end

  # Virtually the same test as above, but add 180° to all longitudes.
  def test_mapping_a_bunch_of_points_straddling_date_line
    data = [
      [10, -175],     # 0 --._____
      [10.1, -175.1], # 1 --'     |_
      [20, -175],     # 2 --------' |_
      [-10, -175],    # 3 -----.____| |
      [-12, -177],    # 4 -----'      |_
      [20, -165],     # 5 -----.______|
      [22, -167],     # 6 -----'      |
      [0, 175],       # 7 ------------'
      [-90, -135],    # 8 --------------
      [70, -145]      # 9 --------------
    ]
    observations = data.map do |lat, long|
      Observation.new(lat: lat, long: long)
    end

    coll = CollapsibleCollectionOfMappableObjects.new(observations,
                                                      observations.length)
    assert_list_of_mapsets(coll, data)

    data[0] = [10.1, 10.0, -175.0, -175.1]
    data[1] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 9)
    assert_list_of_mapsets(coll, data)

    data[3] = [-10, -12, -175, -177]
    data[5] = [22, 20, -165, -167]
    data[4] = data[6] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 8)
    assert_list_of_mapsets(coll, data)
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 7)
    assert_list_of_mapsets(coll, data)

    data[0] = [20, 10, -175, -175.1]
    data[2] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 6)
    assert_list_of_mapsets(coll, data)

    data[0] = [20, -12, -175, -177]
    data[3] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 5)
    assert_list_of_mapsets(coll, data)

    # This is the tricky one: will it combine 175°E with 175°W?
    data[0] = [22, -12, -165, 175]
    data[5] = data[7] = nil
    coll = CollapsibleCollectionOfMappableObjects.new(observations, 4)
    assert_list_of_mapsets(coll, data)
  end
end
