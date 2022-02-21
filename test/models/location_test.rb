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
    bad_location("San Francisco, San Francisco Co., California, USA")
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

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    loc  = locations(:albion)
    desc = location_descriptions(:albion_desc)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)
    location_version = loc.version
    description_version = desc.version

    desc.authors.clear
    desc.editors.clear
    desc.reload

    rolf.email_locations_admin  = false
    rolf.email_locations_author = true
    rolf.email_locations_editor = false
    rolf.email_locations_all    = false
    rolf.save

    mary.email_locations_admin  = false
    mary.email_locations_author = true
    mary.email_locations_editor = false
    mary.email_locations_all    = false
    mary.save

    dick.email_locations_admin  = false
    dick.email_locations_author = true
    dick.email_locations_editor = false
    dick.email_locations_all    = true
    dick.save

    assert_equal(0, desc.authors.length)
    assert_equal(0, desc.editors.length)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       x       .
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
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::LocationChange",
                 from: rolf,
                 to: dick,
                 location: loc.id,
                 description: desc.id,
                 old_location_version: loc.version,
                 new_location_version: loc.version,
                 old_description_version: desc.version - 1,
                 new_description_version: desc.version)

    # Dick wisely reconsiders getting emails for every location change.
    # Have Mary opt in for all temporarily just to make sure she doesn't
    # send herself emails when she changes things.
    dick.email_locations_all = false
    dick.save
    mary.email_locations_all = true
    mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       x       .
    # 3 Dick:       x       .       .       .
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
    assert_equal(1, QueuedEmail.count)

    # Have Mary opt back out.
    mary.email_locations_all = false
    mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       .       .
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
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
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

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       .       .       .       .
    # 3 Dick:       x       .       .       .
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
    assert_equal(2, QueuedEmail.count)

    # Have everyone request editor-notifications and have Dick change it again.
    # Only Rolf should get notified since Mary is an author, not an editor, and
    # Dick shouldn't send himself notifications.
    mary.email_locations_editor = true
    mary.save
    rolf.email_locations_editor = true
    rolf.save
    dick.email_locations_editor = true
    dick.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       .
    # 2 Mary:       .       x       .       .
    # 3 Dick:       x       x       .       .
    # Authors: Mary   editors: Rolf, Dick
    User.current = dick
    desc.reload
    desc.notes = "Dick changed it again."
    desc.save
    assert_equal(description_version + 5, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(mary, desc.authors.first)
    assert_user_list_equal([rolf, dick], desc.editors)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
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

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       no
    # 2 Mary:       .       x       .       yes
    # 3 Dick:       x       x       .       yes
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
    assert_user_list_equal([rolf, dick], desc.editors)
    assert_email(3,
                 flavor: "QueuedEmail::LocationChange",
                 from: dick,
                 to: mary,
                 location: loc.id,
                 description: desc.id,
                 old_location_version: loc.version - 1,
                 new_location_version: loc.version,
                 old_description_version: desc.version,
                 new_description_version: desc.version)
    assert_equal(4, QueuedEmail.count)
    QueuedEmail.queue_emails(false)
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
    I18n.locale = "es"
    loc3 = Location.unknown
    assert_objs_equal(loc1, loc3)
    TranslationString.translations(:es)[:unknown_locations] = "Desconocido"
    loc4 = Location.unknown
    assert_objs_equal(loc1, loc4)
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
    loc2.merge(loc1)
    obj.reload
    assert_equal(loc2.id, obj.location_id)
  end

  def test_change_scientific_name
    loc = Location.first

    User.current = rolf
    assert_equal(:postal, User.current_location_format)
    loc.update_attribute(:display_name, "One, Two, Three")
    assert_equal("One, Two, Three", loc.name)
    assert_equal("Three, Two, One", loc.scientific_name)

    User.current = roy
    assert_equal(:scientific, User.current_location_format)
    loc.update_attribute(:display_name, "Un, Deux, Trois")
    assert_equal("Trois, Deux, Un", loc.name)
    assert_equal("Un, Deux, Trois", loc.scientific_name)
  end

  def test_force_valid_lat_longs
    loc = locations(:albion)

    # Make sure a good location is unchanged.
    loc.north = 8
    loc.south = 6
    loc.east = 4
    loc.west = 2
    loc.force_valid_lat_longs!
    assert_equal([8, 6, 4, 2], [loc.north, loc.south, loc.east, loc.west])

    # Make sure north/south reversed is fixed.
    loc.north = -8
    loc.south = 6
    loc.east = 4
    loc.west = 2
    loc.force_valid_lat_longs!
    assert_equal([-0.9999, -1.0001, 3.0001, 2.9999],
                 [loc.north, loc.south, loc.east, loc.west])

    # Make sure point is expanded to tiny box.
    loc.north = 6
    loc.south = 6
    loc.east = 4
    loc.west = 4
    loc.force_valid_lat_longs!
    assert_equal([6.0001, 5.9999, 4.0001, 3.9999],
                 [loc.north, loc.south, loc.east, loc.west])

    # Make sure good box spanning dateline is unchanged.
    loc.north = 8
    loc.south = 6
    loc.east = -170
    loc.west = 170
    loc.force_valid_lat_longs!
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
    loc2.merge(loc1)
    assert_nil(log1.reload.target_id)
    assert_not_nil(log2.reload.target_id)
    assert_match(/Location merged/, log1.detail)
  end
end
