# frozen_string_literal: true

require("test_helper")

class LocationTest < UnitTestCase
  def bad_location(str)
    assert(Location.dubious_name?(str, true) != [])
  end

  def good_location(str)
    assert_not(Location.dubious_name?(str))
  end

  def test_dubious_name
    bad_location("Albion,California,  USA")
    bad_location("Albion, California")
    bad_location("USA, North America")
    bad_location("San Francisco, USA")
    bad_location("San Francisco, CA, USA")
    # bad_location("Tilden Park, California, USA") - can't detect
    # bad_location("Tilden Park, Kensington, California, USA") - can't detect
    bad_location("Albis Mountain Range, Zurich area, Switzerland")
    # bad_location("Southern California, California, USA") - can't detect
    bad_location("South California, USA")
    bad_location("Western Australia")
    bad_location("Mt Tam SP, Marin County, CA, USA.")
    bad_location("Washington, DC, USA")
    bad_location("bedford, new york, usa")
    bad_location("Hong Kong, China N22.498, E114.178")
    bad_location("Washington DC, USA in wood chips")
    bad_location("Washington DC, USA (near the mall)")
    bad_location("Montréal, Québec, Canada")
    bad_location("10th Ave. & Lincoln Way, San Francisco, CA USA")
    bad_location("Above (about 4800 ft) Chester, California, USA")
    good_location("Albion, California, USA")
    good_location("Unknown")
    good_location("Earth")
    good_location("North America")
    good_location("San Francisco, California, USA")
    good_location("San Francisco, San Francisco Co., California, USA")
    good_location("Tilden Park, Contra Costa Co., California, USA")
    good_location("Albis Mountain Range, near Zurich, Switzerland")
    good_location("Southern California, USA")
    good_location("Western Australia, Australia")
    good_location("Pemberton, Western Australia, Australia")
    good_location("Mount Tamalpais State Park, Marin Co., California, USA")
    good_location("Washington DC, USA")
    good_location("Bedford, New York, USA")
    good_location("Hong Kong, China")
    good_location("Washington DC, USA")
    good_location("The Mall, Washington DC, USA")
    good_location("Montreal, Quebec, Canada")
    good_location("10th Ave. and Lincoln Way, San Francisco, California, USA")
    good_location("near Chester, California, USA")
    good_location("Mexico")
    good_location("Mexico, Mexico")
    good_location("Guanajuato, Mexico")
  end

  def test_understood_country
    assert(Location.understood_country?("USA"))
    assert(Location.understood_country?("Afghanistan"))
    assert_not(Location.understood_country?("Moon"))
  end

  def test_understood_continent
    assert(Location.understood_continent?("Central America"))
    assert_not(Location.understood_continent?("Atlantis"))
    assert(Location.countries_in_continent("Europe").include?("France"))
    assert_not(Location.countries_in_continent("Europe").include?("Canada"))
  end

  def test_versioning
    User.current = mary
    loc = Location.create!(
      name: "Anywhere",
      north: 60,
      south: 50,
      east: 40,
      west: 30
    )
    assert_equal(mary.id, loc.user_id)
    assert_equal(mary.id, loc.versions.last.user_id)
    # Make sure the box_area was calculated correctly
    assert_equal(loc.box_area.round(6), loc.calculate_area.round(6))
    # Make sure the center_lat and center_lng were calculated correctly
    center_lat, center_lng = loc.center
    assert_equal(loc.center_lat, center_lat)
    assert_equal(loc.center_lng, center_lng)

    User.current = rolf
    loc.display_name = "Anywhere, USA"
    loc.save
    assert_equal(mary.id, loc.user_id)
    assert_equal(rolf.id, loc.versions.last.user_id)
    assert_equal(mary.id, loc.versions.first.user_id)

    User.current = dick
    desc = LocationDescription.create!(
      location: loc,
      notes: "Something."
    )
    assert_equal(dick.id, desc.user_id)
    assert_equal(dick.id, desc.versions.last.user_id)
    assert_equal(mary.id, loc.user_id)
    assert_equal(rolf.id, loc.versions.last.user_id)
    assert_equal(mary.id, loc.versions.first.user_id)

    User.current = rolf
    desc.notes = "Something else."
    desc.save
    assert_equal(dick.id, desc.user_id)
    assert_equal(rolf.id, desc.versions.last.user_id)
    assert_equal(dick.id, desc.versions.first.user_id)
  end

  # Method should populate location box_area, center_lat, center_lng
  # and observation location_lat location_lng columns
  def test_update_box_area_and_center_columns
    Location.update_box_area_and_center_columns

    # this Location does not have area or center already set in fixtures
    not_set = locations(:sortable_observation_user_location)
    assert_equal(not_set.center_lat, not_set.calculate_lat,
                 "Location #{not_set.name} should have had center_lat " \
                 "calculated by update_box_area_and_center_columns")
    not_set.observations.find_each do |obs|
      assert_equal(obs.location_lat, not_set.center_lat,
                   "Observation #{obs.name} should have had location_lat " \
                   "copied from #{not_set.name}")
    end
    # Location area / center are in fixtures, but center not set in obs fixtures
    locs = [locations(:burbank), locations(:albion)]
    locs.each do |loc|
      loc.observations.find_each do |obs|
        assert_equal(obs.location_lat, loc.center_lat,
                     "Observation #{obs.name} should have had location_lat " \
                     "copied from #{loc.name}")
      end
    end
    big = locations(:california)
    big.observations.each do |obs|
      assert_nil(obs.location_lat,
                 "Observation #{obs.name} should have had location_lat " \
                 "nil because #{big.name} is too large")
    end
    # Test updating a location box, that the center and area are recalculated
    # and propagated to associated observations
    rey = locations(:point_reyes)
    rey_area = rey.calculate_area.round(4)
    new_bounds = rey.bounding_box.merge(north: 38.2461)
    box = Mappable::Box.new(**new_bounds)
    box_area = box.calculate_area.round(4)
    assert_not_equal(rey_area, box_area)

    rey.update!(**new_bounds)
    assert_equal(rey.center_lat, box.calculate_lat)
    assert_equal(rey.box_area.round(4), box_area)
    rey.observations.each do |obs|
      assert_equal(obs.location_lat, rey.center_lat,
                   "Observation #{obs.name} should have had location_lat " \
                   "copied from #{rey.name}")
    end
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    loc  = locations(:albion)
    desc = location_descriptions(:albion_desc)

    QueuedEmail.queue = true
    QueuedEmail.all.map(&:destroy)
    location_version = loc.version
    description_version = desc.version

    desc.authors.clear
    desc.editors.clear
    desc.reload

    rolf.email_locations_admin  = false
    rolf.email_locations_author = true
    rolf.email_locations_editor = false
    rolf.save

    mary.email_locations_admin  = false
    mary.email_locations_author = true
    mary.email_locations_editor = false
    mary.save

    dick.email_locations_admin  = false
    dick.email_locations_author = true
    dick.email_locations_editor = false
    dick.save

    assert_equal(0, desc.authors.length)
    assert_equal(0, desc.editors.length)

    # email types:  author  editor  interest
    # 1 Rolf:       x       .       .
    # 2 Mary:       x       .       .
    # 3 Dick:       x       .       .
    # Authors: --   editors: --
    # Rolf changes notes: notify Dick (all); Rolf becomes editor.
    User.current = rolf
    desc.reload
    desc.notes = ""
    desc.save
    assert_equal(description_version + 1, desc.version)
    assert_equal(0, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(rolf, desc.editors.first)
    assert_equal(0, QueuedEmail.count)

    # email types:  author  editor  interest
    # 1 Rolf:       x       .       .
    # 2 Mary:       x       .       .
    # 3 Dick:       x       .       .
    # Authors: --   editors: Rolf
    # Mary writes notes: no emails; Mary becomes author.
    User.current = mary
    desc.reload
    desc.notes = "Mary wrote this."
    desc.save
    assert_equal(description_version + 2, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_equal(rolf, desc.editors.first)
    assert_equal(0, QueuedEmail.count)

    # email types:  author  editor  interest
    # 1 Rolf:       x       .       .
    # 2 Mary:       x       .       .
    # 3 Dick:       x       .       .
    # Authors: Mary   editors: Rolf
    # Now when Rolf changes the notes Mary should get notified.
    User.current = rolf
    desc.reload
    desc.notes = "Rolf changed it to this."
    desc.save
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_equal(rolf, desc.editors.first)
    assert_equal(description_version + 3, desc.version)
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::LocationChange",
                 from: rolf,
                 to: mary,
                 location: loc.id,
                 description: desc.id,
                 old_location_version: loc.version,
                 new_location_version: loc.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version)

    # Have Mary opt out of author-notifications to make sure that's why she
    # got the last email.
    mary.email_locations_author = false
    mary.save

    # email types:  author  editor  interest
    # 1 Rolf:       x       .       .
    # 2 Mary:       .       .       .
    # 3 Dick:       x       .       .
    # Authors: Mary   editors: Rolf
    # Have Dick change it to make sure rolf doesn't get an email as he is just
    # an editor and he has opted out of such notifications.
    User.current = dick
    desc.reload
    desc.notes = "Dick changed it now."
    desc.save
    assert_equal(description_version + 4, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
    assert_equal(1, QueuedEmail.count)

    # Have everyone request editor-notifications and have Dick change it again.
    # Only Rolf should get notified since Mary is an author, not an editor, and
    # Dick shouldn't send himself notifications.
    mary.email_locations_editor = true
    mary.save
    rolf.email_locations_editor = true
    rolf.save
    dick.email_locations_editor = true
    dick.save

    # email types:  author  editor  interest
    # 1 Rolf:       x       x       .
    # 2 Mary:       .       x       .
    # 3 Dick:       x       x       .
    # Authors: Mary   editors: Rolf, Dick
    User.current = dick
    desc.reload
    desc.notes = "Dick changed it again."
    desc.save
    assert_equal(description_version + 5, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_user_arrays_equal([rolf, dick], desc.editors)
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
                 flavor: "QueuedEmail::LocationChange",
                 from: dick,
                 to: rolf,
                 location: loc.id,
                 description: desc.id,
                 old_location_version: loc.version,
                 new_location_version: loc.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version)

    # Have Mary and Dick express interest, Rolf express disinterest,
    # then have Dick change it again.  Mary should get an email.
    Interest.create(target: loc, user: rolf, state: false)
    Interest.create(target: loc, user: mary, state: true)
    Interest.create(target: loc, user: dick, state: true)

    # email types:  author  editor  interest
    # 1 Rolf:       x       x       no
    # 2 Mary:       .       x       yes
    # 3 Dick:       x       x       yes
    # Authors: Mary   editors: Rolf, Dick
    User.current = dick
    loc.reload
    loc.display_name = "Another Name"
    loc.save
    assert_equal(location_version + 1, loc.version)
    assert_equal(description_version + 5, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_user_arrays_equal([rolf, dick], desc.editors)
    assert_email(2,
                 flavor: "QueuedEmail::LocationChange",
                 from: dick,
                 to: mary,
                 location: loc.id,
                 description: desc.id,
                 old_location_version: loc.version - 1,
                 new_location_version: loc.version,
                 old_description_version: desc.version,
                 new_description_version: desc.version)
    assert_equal(3, QueuedEmail.count)
    QueuedEmail.queue = false
  end

  def test_parse_latitude
    assert_nil(Location.parse_latitude(""))
    assert_equal(12.3456, Location.parse_latitude("12.3456"))
    assert_equal(-12.3456, Location.parse_latitude(" -12.3456 "))
    assert_nil(Location.parse_latitude("123.456"))
    assert_equal(12.3456, Location.parse_latitude("12.3456N"))
    assert_nil(Location.parse_latitude("12.3456E"))
    assert_equal(12.5824, Location.parse_latitude('12°34\'56.789"N'))
    assert_equal(12.5760, Location.parse_latitude("12 34.56"))
    assert_equal(-12.5760, Location.parse_latitude("-12 34 33.6"))
    assert_equal(-12.5822, Location.parse_latitude(" 12 deg 34 min 56 sec S "))
  end

  def test_parse_longitude
    assert_nil(Location.parse_longitude(""))
    assert_equal(12.3456, Location.parse_longitude("12.3456"))
    assert_equal(-12.3456, Location.parse_longitude(" -12.3456 "))
    assert_nil(Location.parse_longitude("190.456"))
    assert_equal(170.4560, Location.parse_longitude("170.456"))
    assert_equal(12.3456, Location.parse_longitude("12.3456E"))
    assert_nil(Location.parse_longitude("12.3456S"))
    assert_equal(12.5824, Location.parse_longitude('12°34\'56.789"E'))
    assert_equal(12.5760, Location.parse_longitude("12 34.56"))
    assert_equal(-12.5760, Location.parse_longitude("-12 34 33.6"))
    assert_equal(-12.5822, Location.parse_longitude(" 12deg 34min 56sec W "))
  end

  def test_convert_altitude
    assert_nil(Location.parse_altitude(""))
    assert_nil(Location.parse_altitude("blah"))
    assert_equal(123, Location.parse_altitude("123"))
    assert_equal(-123, Location.parse_altitude("-123.456"))
    assert_equal(-124, Location.parse_altitude("-123.567"))
    assert_equal(123, Location.parse_altitude("123m"))
    assert_equal(123, Location.parse_altitude(" 123 m. "))
    assert_equal(37, Location.parse_altitude("123ft"))
    assert_equal(38, Location.parse_altitude("124'"))
  end

  def test_unknown
    loc = locations(:unknown_location)
    assert_objs_equal(loc, Location.unknown)
    assert(Location.names_for_unknown.include?("Unknown"))
    assert(Location.names_for_unknown.include?("Earth"))
    assert_true(Location.is_unknown?("Unknown"))
    assert_true(Location.is_unknown?("Earth"))
    assert_true(Location.is_unknown?("World"))
    assert_true(Location.is_unknown?("Anywhere"))
  end

  def test_unknown2
    loc1 = locations(:unknown_location)
    loc2 = Location.unknown
    assert_objs_equal(loc1, loc2)
    I18n.with_locale(:es) do
      loc3 = Location.unknown
      assert_objs_equal(loc1, loc3)
      TranslationString.store_localizations(
        :es, { unknown_locations: "Desconocido" }
      )
      loc4 = Location.unknown
      assert_objs_equal(loc1, loc4)
    end
  end

  def test_merge_with_user
    do_merge_test(rolf)
  end

  def test_merge_with_species_lists
    do_merge_test(SpeciesList.first)
  end

  def test_merge_with_observation
    do_merge_test(Observation.last)
  end

  def do_merge_test(obj)
    loc1 = locations(:albion)
    loc2 = locations(:nybg_location)
    obj.update_attribute(:location, loc1)
    obj.reload
    assert_equal(loc1.id, obj.location_id)
    loc2.merge(rolf, loc1)
    obj.reload
    assert_equal(loc2.id, obj.location_id)
  end

  def test_change_scientific_name
    loc = Location.first

    User.current = rolf
    assert_equal("postal", User.current_location_format)
    loc.update_attribute(:display_name, "One, Two, Three")
    assert_equal("One, Two, Three", loc.name)
    assert_equal("Three, Two, One", loc.scientific_name)

    User.current = roy
    assert_equal("scientific", User.current_location_format)
    loc.update_attribute(:display_name, "Un, Deux, Trois")
    assert_equal("Trois, Deux, Un", loc.name)
    assert_equal("Un, Deux, Trois", loc.scientific_name)
  end

  def test_force_valid_lat_lngs
    loc = locations(:albion)

    # Make sure a good location is unchanged.
    loc.north = 8
    loc.south = 6
    loc.east = 4
    loc.west = 2
    loc.force_valid_lat_lngs!
    assert_equal([8, 6, 4, 2], [loc.north, loc.south, loc.east, loc.west])

    # Make sure north/south reversed is fixed.
    loc.north = -8
    loc.south = 6
    loc.east = 4
    loc.west = 2
    loc.force_valid_lat_lngs!
    assert_equal([-0.9999, -1.0001, 3.0001, 2.9999],
                 [loc.north, loc.south, loc.east, loc.west])

    # Make sure point is expanded to tiny box.
    loc.north = 6
    loc.south = 6
    loc.east = 4
    loc.west = 4
    loc.force_valid_lat_lngs!
    assert_equal([6.0001, 5.9999, 4.0001, 3.9999],
                 [loc.north, loc.south, loc.east, loc.west])

    # Make sure good box spanning dateline is unchanged.
    loc.north = 8
    loc.south = 6
    loc.east = -170
    loc.west = 170
    loc.force_valid_lat_lngs!
    assert_equal([8, 6, -170, 170], [loc.north, loc.south, loc.east, loc.west])
  end

  def test_destroy_orphans_log
    loc = locations(:mitrula_marsh)
    log = loc.rss_log
    assert_not_nil(log)
    loc.destroy!
    assert_nil(log.reload.target_id)
  end

  def test_merge_orphans_log
    loc1 = locations(:mitrula_marsh)
    loc2 = locations(:albion)
    log1 = loc1.rss_log
    log2 = loc2.rss_log
    assert_not_nil(log1)
    assert_not_nil(log2)
    loc2.merge(rolf, loc1)
    assert_nil(log1.reload.target_id)
    assert_not_nil(log2.reload.target_id)
    assert_equal(:log_orphan, log1.parse_log[0][0])
    assert_equal(:log_location_merged, log1.parse_log[1][0])
  end

  # test BoxMethods module `lat_lng_close?` method
  def test_lat_lng_close
    loc = locations(:east_lt_west_location)
    # The centrum of the location is provided by BoxMethods#center, lat, lng
    assert_true(loc.lat_lng_close?(loc.calculate_lat, loc.calculate_lng),
                "Location's centrum should be 'close' to Location.")
    assert_false(loc.lat_lng_close?(loc.calculate_lat, loc.calculate_lng + 180),
                 "Opposite side of globe should not be 'close' to Location.")
  end

  # ----------------------------------------------------
  #  Scopes
  #    Explicit tests of some scopes to improve coverage
  # ----------------------------------------------------

  def test_scope_name_has
    assert_includes(
      Location.name_has("Albion"),
      locations(:albion)
    )
    assert_empty(Location.name_has(ARBITRARY_SHA))
  end

  def test_scope_one_region
    assert_includes(
      Location.one_region("New York, USA"),
      locations(:nybg_location)
    )
    assert_not_includes(
      Location.one_region("York"),
      locations(:nybg_location),
      "Entire trailing part of Location name should match region"
    )
    assert_empty(Location.one_region(ARBITRARY_SHA))
  end

  def test_scope_region
    expects = Location.region(["California, USA", "New York, USA"]).
              reorder(id: :asc)
    assert_includes(expects, locations(:nybg_location))
    assert_includes(expects, albion)
    assert_includes(expects, california)
    assert_not_includes(expects, wrangel)
    assert_not_includes(expects, perkatkun)
  end

  def test_contains_edges
    loc = albion
    assert(loc.contains_lat?(loc.north), "Location should contain its N edge")
    assert(loc.contains_lat?(loc.south), "Location should contain its S edge")
    assert(loc.contains_lng?(loc.west), "Location should contain its W edge")
    assert(loc.contains_lng?(loc.east), "Location should contain its E edge")
  end

  def test_scope_contains_point
    [
      locations(:albion),
      locations(:perkatkun),
      locations(:east_lt_west_location)
    ].each { |loc| contains_corners(loc) }
  end

  def contains_corners(loc)
    assert(Location.contains_point(lat: loc.north, lng: loc.east).
      include?(loc), "#{loc.name} should contain its NE corner")
    assert(Location.contains_point(lat: loc.south, lng: loc.west).
      include?(loc), "#{loc.name} should contain its SW corner")
  end

  def cal
    locations(:california)
  end

  def missing_west_box
    { north: cal.north, south: cal.south, east: cal.east }
  end

  def outa_bounds_box
    { north: 91, south: cal.south, east: cal.east, west: cal.west }
  end

  def north_southerthan_south_box
    { north: cal.south - 10, south: cal.south, east: cal.east, west: cal.west }
  end

  # supplements API tests
  def test_scope_in_box
    cal = locations(:california)
    locs_in_cal_box = Location.in_box(**cal.bounding_box)
    assert_includes(locs_in_cal_box, locations(:albion))
    assert_includes(locs_in_cal_box, cal)

    wrangel = locations(:east_lt_west_location)
    locs_in_wrangel_box = Location.in_box(**wrangel.bounding_box)
    assert_includes(locs_in_wrangel_box, wrangel)
    assert_not_includes(locs_in_wrangel_box, cal)

    assert_empty(
      Location.in_box(**missing_west_box),
      "`scope: in_box` should be empty if an argument is missing"
    )
    assert_empty(
      Location.in_box(**outa_bounds_box),
      "`scope: in_box` should be empty if an argument is out of bounds"
    )
    assert_empty(
      Location.in_box(**north_southerthan_south_box),
      "`scope: in_box` should be empty if N < S"
    )
  end

  def test_scope_contains_box
    # loc doesn't straddle 180
    #   potential br (bounding rectangle, external_loc) to "left" of loc
    do_contains_box(loc: albion, external_loc: perkatkun,
                    regions: [california, earth])

    #   potential br overlaps only "left" side of loc
    overlaps_albion_west =
      Location.create(
        name: "overlaps_albion_west", user: users(:rolf),
        north: albion.north, south: albion.south, east: albion.east - 0.05,
        west: albion.west - 0.05
      )
    do_contains_box(loc: albion, external_loc: overlaps_albion_west)

    #   potential br overlaps only "right" side of loc
    overlaps_albion_east =
      Location.create(
        name: "overlaps_albion_east", user: users(:rolf),
        north: albion.north, south: albion.south, west: albion.west + 0.05,
        east: albion.east + 0.05
      )
    do_contains_box(loc: albion, external_loc: overlaps_albion_east)

    #   potential br (bounding rectangle) entirely to "right" of loc
    nybg = locations(:nybg_location)
    do_contains_box(loc: albion, external_loc: nybg)

    # loc straddles 180
    #   potential br entirely outside of loc
    russia = Location.create(
      name: "russia", user: users(:rolf),
      north: 86.217, south: 38.083, west: 27.370116, east: -168.995128
    )
    do_contains_box(loc: wrangel, external_loc: albion,
                    regions: [russia, earth])
    #   potential br overlaps only "left" side of loc
    overlaps_wrangel_west =
      Location.create(
        name: "overlaps_wrangel_west", user: users(:rolf),
        north: wrangel.north, south: wrangel.south, east: wrangel.east - 0.05,
        west: wrangel.west - 0.05
      )
    do_contains_box(loc: wrangel, external_loc: overlaps_wrangel_west)

    #   potential br overlaps only "right" side of loc
    overlaps_wrangel_east =
      Location.create(
        name: "overlaps_wrangel_east", user: users(:rolf),
        north: wrangel.north, south: wrangel.south, east: wrangel.east + 0.05,
        west: wrangel.west + 0.05
      )
    do_contains_box(loc: wrangel, external_loc: overlaps_wrangel_east)

    # These failed depending on the rounding correction used by `contains_box`
    do_contains_box(loc: perkatkun, regions: [wrangel, earth])
    do_contains_box(loc: california, regions: [earth])
  end

  def test_scope_with_minimum_bounding_box_containing_point
    falmouth = locations(:falmouth)
    assert_equal(
      falmouth,
      Location.with_minimum_bounding_box_containing_point(
        lat: falmouth.center_lat, lng: falmouth.center_lng
      )
    )

    california_locations = Location.where(Location[:name] =~ /California, USA$/)
    assert_empty(
      california_locations.with_minimum_bounding_box_containing_point(
        lat: falmouth.center_lat, lng: falmouth.center_lng
      )
    )
  end

  def albion
    locations(:albion)
  end

  def california
    locations(:california)
  end

  def earth
    locations(:unknown_location)
  end

  def perkatkun
    locations(:perkatkun)
  end

  def wrangel
    locations(:east_lt_west_location)
  end

  def do_contains_box(loc:, external_loc: nil,
                      regions: [locations(:unknown_location)])
    containers = Location.contains_box(**loc.bounding_box)

    assert_includes(containers, loc,
                    "Location #{loc.name} should contain itself")
    regions.each do |region|
      assert_includes(
        containers, region,
        "#{region.name} should contain #{loc.name}"
      )
    end
    return if external_loc.blank?

    assert_not_includes(
      containers, external_loc,
      "#{external_loc.name} shouldn't contain #{loc.name}"
    )
  end

  def test_hidden
    User.current = mary
    high = 60.234
    low = 60.123
    loc = Location.create!(
      hidden: true,
      name: "Somewhere Hidden",
      north: high,
      south: low,
      east: high,
      west: low
    )
    assert_equal(loc.north, high.ceil(1))
    assert_equal(loc.south, low.floor(1))
    assert_equal(loc.east, high.ceil(1))
    assert_equal(loc.west, low.floor(1))
  end
end
