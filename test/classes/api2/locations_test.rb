# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::LocationsTest < UnitTestCase
  include API2Extensions

  def test_basic_location_get
    do_basic_get_test(Location)
  end

  # ------------------------------
  #  :section: Location Requests
  # ------------------------------

  def params_get(**)
    { method: :get, action: :location }.merge(**)
  end

  def loc_sample
    @loc_sample ||= Location.all.sample
  end

  def test_getting_locations_id
    assert_api_pass(params_get(id: loc_sample.id))
    assert_api_results([loc_sample])
  end

  def loc_samples
    @loc_samples ||= Location.all.sample(12)
  end

  def test_getting_locations_ids
    assert_api_pass(params_get(id: loc_samples.map(&:id).join(",")))
    assert_api_results(loc_samples)
  end

  def test_getting_locations_created_at
    locs = Location.where(Location[:created_at].year.eq(2008))
    assert_not_empty(locs)
    assert_api_pass(params_get(created_at: "2008"))
    assert_api_results(locs)
  end

  def test_getting_locations_updated_at
    locs = Location.updated_on("2012-01-01")
    assert_not_empty(locs)
    assert_api_pass(params_get(updated_at: "2012-01-01"))
    assert_api_results(locs)
  end

  def test_getting_locations_user
    locs = Location.where(user: rolf)
    assert_not_empty(locs)
    assert_api_pass(params_get(user: "rolf"))
    assert_api_results(locs)
  end

  def test_getting_locations_in_box
    locs = Location.in_box(north: 40, south: 39, east: -123, west: -124)
    assert_not_empty(locs)
    assert_api_fail(params_get(south: 39, east: -123, west: -124))
    assert_api_fail(params_get(north: 40, east: -123, west: -124))
    assert_api_fail(params_get(north: 40, south: 39, west: -124))
    assert_api_fail(params_get(north: 40, south: 39, east: -123))
    assert_api_pass(params_get(north: 40, south: 39, east: -123, west: -124))
    assert_api_results(locs)
  end

  def test_posting_locations
    name1  = "Reno, Nevada, USA"
    name2  = "Sparks, Nevada, USA"
    name3  = "Evil Lair, Latveria"
    name4  = "Nowhere, East Paduka, USA"
    name5  = "Washoe County, Nevada, USA"
    @name  = name1
    @north = 39.64
    @south = 39.39
    @east  = -119.70
    @west  = -119.94
    @high  = 1700
    @low   = 1350
    @notes = "Biggest Little City"
    @user  = rolf
    params = {
      method: :post,
      action: :location,
      api_key: @api_key.key,
      name: @name,
      north: @north,
      south: @south,
      east: @east,
      west: @west,
      high: @high,
      low: @low,
      notes: @notes
    }
    assert_api_pass(params)
    assert_last_location_correct
    assert_api_fail(params)
    assert_api_fail(params.merge(name: name3))
    assert_api_fail(params.merge(name: name4))
    assert_api_fail(params.merge(name: name5))
    params[:name] = @name = name2
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:name))
    assert_api_fail(params.except(:north))
    assert_api_fail(params.except(:south))
    assert_api_fail(params.except(:east))
    assert_api_fail(params.except(:west))
    assert_api_fail(params.except(:north, :south, :east, :west))
    assert_api_pass(params.except(:high, :low, :notes))
    @high = @low = @notes = nil
    assert_last_location_correct
  end

  def test_patching_locations
    albion = locations(:albion)
    burbank = locations(:burbank)
    params = {
      method: :patch,
      action: :location,
      api_key: @api_key.key,
      id: albion.id,
      set_name: "Reno, Nevada, USA",
      set_north: 39.64,
      set_south: 39.39,
      set_east: -119.70,
      set_west: -119.94,
      set_high: 1700,
      set_low: 1350,
      set_notes: "Biggest Little City"
    }

    # Just to be clear about the starting point, the only objects attached to
    # this location at first are some versions and a description, all owned by
    # rolf, the same user who created the location.  So it should be modifiable
    # as it is.  The plan is to temporarily attach one object at a time to make
    # sure it is *not* modifiable if anything is wrong.
    assert_objs_equal(rolf, albion.user)
    assert_not_empty(albion.versions.select { |v| v.user_id == rolf.id })
    assert_not_empty(albion.descriptions.select { |v| v.user == rolf })
    assert_empty(albion.versions.reject { |v| v.user_id == rolf.id })
    assert_empty(albion.descriptions.reject { |v| v.user == rolf })
    assert_empty(albion.observations)
    assert_empty(albion.species_lists)
    assert_empty(albion.users)
    assert_empty(albion.herbaria)

    # Not allowed to change if anyone else has an observation there.
    obs = observations(:minimal_unknown_obs)
    assert_objs_equal(mary, obs.user)
    obs.update!(location: albion)
    assert_api_fail(params)
    obs.update!(location: burbank)

    # But allow it if rolf owns that observation.
    obs = observations(:coprinus_comatus_obs)
    assert_objs_equal(rolf, obs.user)
    obs.update!(location: albion)

    # Not allowed to change if anyone else has a species_list there.
    spl = species_lists(:unknown_species_list)
    assert_objs_equal(mary, spl.user)
    spl.update!(location: albion)
    assert_api_fail(params)
    spl.update!(location: burbank)

    # But allow it if rolf owns that list.
    spl = species_lists(:first_species_list)
    assert_objs_equal(rolf, spl.user)
    spl.update!(location: albion)

    # Not allowed to change if anyone has made this their personal location.
    mary.update!(location: albion)
    assert_api_fail(params)
    mary.update!(location: burbank)

    # But allow it if rolf is that user.
    rolf.update!(location: albion)

    # Not allowed to change if an herbarium is at that location, period.
    nybg = herbaria(:nybg_herbarium)
    nybg.update!(location: albion)
    assert_api_fail(params)
    nybg.update!(location: burbank)

    # Not allowed to change if user didn't create it.
    albion.update!(user: mary)
    assert_api_fail(params)
    albion.update!(user: rolf)

    # Okay, permissions should be right, now.  Proceed to "normal" tests.  That
    # is, make sure api key is required, and that name is valid and not already
    # taken.
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(set_name: ""))
    assert_api_fail(params.merge(set_name: "Evil Lair, Latveria"))
    assert_api_fail(params.merge(set_name: burbank.display_name))
    assert_api_fail(params.merge(set_north: "", set_south: "", set_west: "",
                                 set_east: ""))
    assert_api_pass(params)

    albion.reload
    assert_equal("Reno, Nevada, USA", albion.display_name)
    assert_in_delta(39.64, albion.north, MO.box_epsilon)
    assert_in_delta(39.39, albion.south, MO.box_epsilon)
    assert_in_delta(-119.70, albion.east, MO.box_epsilon)
    assert_in_delta(-119.94, albion.west, MO.box_epsilon)
    assert_in_delta(1700, albion.high, MO.box_epsilon)
    assert_in_delta(1350, albion.low, MO.box_epsilon)
    assert_equal("Biggest Little City", albion.notes)
  end

  def test_deleting_locations
    loc = rolf.locations.sample
    params = {
      method: :delete,
      action: :location,
      api_key: @api_key.key,
      id: loc.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end
end
