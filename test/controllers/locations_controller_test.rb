# frozen_string_literal: true

require("test_helper")

class LocationsControllerTest < FunctionalTestCase
  # EMAIL TESTS, currently in Names, Locations and their Descriptions
  # Has to be defined on class itself, include doesn't seem to work
  def self.report_email(email)
    @@emails ||= []
    @@emails << email
  end

  def setup
    @new_pts  = 10
    @chg_pts  = 10
    @auth_pts = 100
    @edit_pts = 10
    @@emails = []
    super
  end

  def assert_email_generated
    assert_not_empty(@@emails, "Was expecting an email notification.")
  ensure
    @@emails = []
  end

  def assert_no_emails
    msg = @@emails.join("\n")
    assert(@@emails.empty?,
           "Wasn't expecting any email notifications; got:\n#{msg}")
  ensure
    @@emails = []
  end

  # Init params based on existing location.
  def update_params_from_loc(loc)
    { id: loc.id,
      location: {
        display_name: loc.display_name,
        north: loc.north,
        west: loc.west,
        east: loc.east,
        south: loc.south,
        high: loc.high,
        low: loc.low,
        notes: loc.notes
      } }
  end

  # A location that isn't in fixtures.
  def barton_flats_params
    name = "Barton Flats, California, USA"
    {
      display_name: name,
      location: {
        display_name: name,
        north: 34.1865,
        west: -116.924,
        east: -116.88,
        south: 34.1571,
        high: 2000.0,
        low: 1600.0,
        notes: "This is now Barton Flats"
      }
    }
  end

  # Post a change that fails -- make sure no new version created.
  def location_error(page, params)
    loc_count = Location.count
    past_loc_count = Location::Version.count
    desc_count = LocationDescription.count
    past_desc_count = LocationDescription::Version.count
    case page
    when :create
      post_requires_login(page, params)
      assert_template("new")
    when :update
      put_requires_login(page, params)
      assert_template("edit")
    end
    assert_template("locations/_form")
    assert_template("shared/_textilize_help")
    assert_equal(loc_count, Location.count)
    assert_equal(past_loc_count, Location::Version.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_desc_count, LocationDescription::Version.count)
  end

  # Post "create" with errors.
  def construct_location_error(params)
    location_error(:create, params)
  end

  # Put "update" with errors.
  def update_location_error(params)
    location_error(:update, params)
  end

  ##############################################################################
  #
  #    SHOW

  def test_show_location
    location = locations(:albion)
    updated_at = location.updated_at
    log_updated_at = location.rss_log.updated_at
    login
    get(:show, params: { id: location.id })
    assert_template("show")
    assert_template("locations/show/_notes")
    assert_template("comments/_comments_for_object")
    assert_template("locations/show/_general_description_panel")

    location.reload
    assert_equal(updated_at, location.updated_at)
    assert_equal(log_updated_at, location.rss_log.updated_at)
  end

  def test_show_location_admin_mode
    login("mary")
    make_admin("mary")
    location = locations(:albion)
    get(:show, params: { id: location.id })
  end

  def assert_show_location
    assert_template("locations/show")
    assert_template("locations/show/_notes")
    assert_template("comments/_comments_for_object")
    assert_template("locations/show/_general_description_panel")
  end

  def test_interest_in_show_location
    # No interest in this location yet.
    albion = locations(:albion)
    login("rolf")
    get(:show, params: { id: albion.id })
    assert_show_location
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: 1))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: -1))

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.new(target: albion, user: rolf, state: true).save
    get(:show, params: { id: albion.id })
    assert_show_location
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: 0))
    assert_image_link_in_html(/ignore.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: -1))

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.new(target: albion, user: rolf, state: false).save
    get(:show, params: { id: albion.id })
    assert_show_location
    assert_image_link_in_html(/halfopen.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: 0))
    assert_image_link_in_html(/watch.*\.png/,
                              set_interest_path(type: "Location",
                                                id: albion.id, state: 1))
  end

  ##############################################################################
  #
  #    INDEX

  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of @index_subaction_param_keys
  # miscellaneous tests using get(:index)
  def test_index
    login
    get(:index)

    assert_displayed_title("Locations by Name")
  end

  def test_index_with_non_default_sort
    sort_order = "num_views"

    login
    get(:index, params: { by: sort_order })

    assert_displayed_title("Locations by Popularity")
  end

  def test_index_bounding_box
    north = south = east = west = 0
    delta = 0.001
    login
    get(:index,
        params: { north: north, south: south, east: east, west: west })
    query = Query.find(QueryRecord.last.id)

    assert_equal(north + delta, query.params[:north])
    assert_equal(south - delta, query.params[:south])
    assert_equal(east + delta, query.params[:east])
    assert_equal(west - delta, query.params[:west])

    get(:index,
        params: { north: 90, south: -90, east: 180, west: -180 })
    query = Query.find(QueryRecord.last.id)
    assert_equal(90, query.params[:north])
    assert_equal(-90, query.params[:south])
    assert_equal(180, query.params[:east])
    assert_equal(-180, query.params[:west])
  end

  def test_index_advanced_search
    query = Query.lookup_and_save(:Location, :advanced_search,
                                  location: "California")
    login
    get(:index,
        params: @controller.query_params(query).merge(advanced_search: true))

    assert_response(:success)
    assert_template("index")
    assert_displayed_title("Advanced Search")
  end

  def test_index_advanced_search_error
    query_without_conditions = Query.lookup_and_save(
      :Location, :advanced_search
    )

    login
    get(:index,
        params: @controller.query_params(query_without_conditions).
                            merge(advanced_search: true))

    assert_flash_error(:runtime_no_conditions.l)
    assert_redirected_to(search_advanced_path)
  end

  def test_index_pattern
    search_str = "California"

    login
    get(:index, params: { pattern: search_str })

    assert_displayed_title("Locations Matching ‘#{search_str}’")
  end

  def test_index_pattern_id
    loc = locations(:salt_point)

    login
    get(:index, params: { pattern: loc.id.to_s })
    assert_redirected_to(location_path(loc.id))
  end

  def test_index_country
    country = "USA"

    login
    get(:index, params: { country: country })

    # Use a regexp because the title is buggy and may change. jdc 2023-02-23.
    # https://www.pivotaltracker.com/story/show/184554008
    assert_displayed_title(/^Locations Matching ‘#{country}.?’/)
    assert_select(
      "#content a:match('href', ?)", %r{#{locations_path}/\d+},
      { count: Location.where(Location[:name].matches("%#{country}")).count },
      "Wrong number of Locations"
    )
  end

  def test_index_country_includes_state_named_after_other_country
    country = "USA"
    new_mexico = create_new_mexico_location

    login
    get(:index, params: { country: country })

    assert_displayed_title(/^Locations Matching ‘#{country}.?’/)
    assert_select(
      "#content a:match('href', ?)", /#{location_path(new_mexico)}/,
      true,
      "USA page should include New Mexico"
    )
  end

  def create_new_mexico_location
    Location.create!(name: "Santa Fe, New Mexico, USA",
                     north: 34.1865,
                     west: -116.924,
                     east: -116.88,
                     south: 34.1571,
                     notes: "Santa Fe",
                     user: mary)
  end

  def test_index_country_excludes_state_with_same_name_in_other_country
    country = "Mexico"
    new_mexico = create_new_mexico_location

    login
    get(:index, params: { country: country })

    assert_select(
      "#content a:match('href', ?)", /^#{location_path(new_mexico)}/,
      { count: 0 },
      "Mexico page should not include New Mexico, USA"
    )
  end

  def test_index_country_missing_country_with_apostrophe
    country = "Cote d'Ivoire"

    login
    get(:index, params: { country: country })

    assert_template("index")
    assert_flash_text(:runtime_no_matches.l(type: :locations.l))
  end

  def test_index_by_user_who_created_multiple_locations
    user = rolf

    login
    get(:index, params: { by_user: user.id })

    assert_template("index")
    assert_displayed_title("Locations created by #{user.name}")
    assert_select(
      "#content a:match('href', ?)", %r{#{locations_path}/\d+},
      { count: Location.where(user: user).count },
      "Wrong number of Locations"
    )
  end

  def test_index_by_user_who_created_one_location
    user = roy
    assert(Location.where(user: user).one?)

    login
    get(:index, params: { by_user: user.id })

    assert_response(:redirect)
    assert_match(location_path(Location.where(user: user).first),
                 redirect_to_url)
  end

  def test_index_by_user_who_created_zero_locations
    user = users(:zero_user)

    login
    get(:index, params: { by_user: user.id })

    assert_template("index")
    assert_flash_text(:runtime_no_matches.l(type: :locations.l))
  end

  def test_index_by_user_bad_user_id
    bad_user_id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { by_user: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(locations_path)
  end

  def test_index_by_editor_of_multiple_locations
    user = roy
    locs_edited_by_user = Location.joins(:versions).
                          where.not(user: user).
                          where(versions: { user_id: user.id })
    assert(locs_edited_by_user.many?)

    login
    get(:index, params: { by_editor: user.id })

    assert_displayed_title("Locations Edited by #{user.name}")
    assert_select("a:match('href',?)", %r{^/locations/\d+},
                  { count: locs_edited_by_user.count },
                  "Wrong number of results")
  end

  def test_index_by_editor_of_one_location
    user = katrina
    locs_edited_by_user = Location.joins(:versions).
                          where.not(user: user).
                          where(versions: { user_id: user.id })
    assert(locs_edited_by_user.one?)

    login
    get(:index, params: { by_editor: user.id })

    assert_response(:redirect)
    assert_match(location_path(locs_edited_by_user.first), redirect_to_url)
  end

  def test_index_by_editor_of_zero_locations
    user = users(:zero_user)

    login
    get(:index, params: { by_editor: user.id })

    assert_template("index")
    assert_flash_text(:runtime_no_matches.l(type: :locations.l))
  end

  def test_index_by_editor_bad_user_i
    bad_user_id = observations(:minimal_unknown_obs).id

    login
    get(:index, params: { by_editor: bad_user_id })

    assert_flash_text(
      :runtime_object_not_found.l(type: "user", id: bad_user_id)
    )
    assert_redirected_to(locations_path)
  end

  ##############################################################################
  #
  #    NEW

  def test_create_location
    requires_login(:new)
    assert_form_action(action: :create)
  end

  # This was causing a crash in live server.
  def test_construct_location_empty_form
    login("mary")
    post(:create,
         params: {
           where: "",
           approved_where: "",
           location: { display_name: "" }
         })
  end

  # Test a simple location creation.
  def test_construct_location_simple
    count = Location.count
    params = barton_flats_params
    display_name = params[:display_name]

    post_requires_login(:create, params)
    loc = assigns(:location)

    assert_redirected_to(location_path(loc.id))
    assert_equal(count + 1, Location.count)
    assert_equal(@new_pts + 10, rolf.reload.contribution)
    # Make sure it's the right Location
    assert_equal(display_name, loc.display_name)

    # find_by_name_or_reverse_name is an MO method, not a Rails finder.
    # We used to have to disable a cop for this, but that seems no longer
    # to be the case. [JPH 2021-09-18]
    loc = Location.find_by_name_or_reverse_name(display_name)
    assert_nil(loc.description)
    assert_not_nil(loc.rss_log)
  end

  def test_construct_location_name_errors
    # Test creating a location with a dubious location name
    params = barton_flats_params
    params[:location][:display_name] = "Somewhere Dubious"
    construct_location_error(params)
  end

  def test_construct_location_screwy_names
    login("dick")
    loc = locations(:burbank)
    params = update_params_from_loc(loc)
    params.delete(:id)

    params[:location][:display_name] = ""
    post(:create, params: params)
    assert_response(:success) # means failure!

    params[:location][:display_name] = " Strip  This,  Maine,  USA "
    post(:create, params: params)
    assert_response(:redirect)
    assert_equal("Strip This, Maine, USA", Location.last.display_name)
  end

  def test_construct_location_errors
    # Test for north > 90
    params = barton_flats_params
    params[:location][:north] = 100
    construct_location_error(params)

    # Test for south < -90
    params = barton_flats_params
    params[:location][:south] = -100
    construct_location_error(params)

    # Test for north < south
    params = barton_flats_params
    north = params[:location][:north]
    params[:location][:north] = params[:location][:south]
    params[:location][:south] = north
    construct_location_error(params)

    # Test for west < -180
    params = barton_flats_params
    params[:location][:west] = -200
    construct_location_error(params)

    # Test for west > 180
    params = barton_flats_params
    params[:location][:west] = 200
    construct_location_error(params)

    # Test for east < -180
    params = barton_flats_params
    params[:location][:east] = -200
    construct_location_error(params)

    # Test for east > 180
    params = barton_flats_params
    params[:location][:east] = 200
    construct_location_error(params)

    # Test for high < low
    params = barton_flats_params
    high = params[:location][:high]
    params[:location][:high] = params[:location][:low]
    params[:location][:low] = high
    construct_location_error(params)
  end

  ##############################################################################
  #
  #    EDIT

  def test_edit_location
    loc = locations(:albion)
    params = { id: loc.id.to_s }
    requires_login(:edit, params)
    assert_form_action({ action: :update, id: loc.id.to_s,
                         approved_where: loc.display_name })
    assert_input_value(:location_display_name, loc.display_name)
  end

  def test_edit_locked_location
    location = locations(:albion)
    location.update(locked: true)
    login(mary.login)

    get(:edit, params: { id: location.id })

    assert_select(
      "input:match('name', ?)", /location/, { minimum: 2 },
      "Location form for locked Location should have location input fields"
    ) do |location_input_fields|
      location_input_fields.each do |field|
        assert_equal(
          "hidden", field["type"],
          "Location input fields should be hidden for locked Locations"
        )
      end
    end
  end

  def test_edit_unknown_location
    loc = locations(:unknown_location)
    old_loc_display_name = loc.display_name
    params = { id: loc.id,
               location: { display_name: "Rome, Italy" } }
    put_requires_login(:update, params)

    assert_equal(old_loc_display_name, loc.reload.display_name,
                 "Users should not be able to change Unknown location")
  end

  def test_update_location
    count = Location::Version.count
    count2 = LocationDescription::Version.count
    contrib = rolf.contribution

    # Turn Albion into Barton Flats.
    loc = locations(:albion)
    updated_at = loc.updated_at
    log_updated_at = loc.rss_log.updated_at
    old_params = update_params_from_loc(loc)
    params = barton_flats_params
    params[:location][:display_name] =
      Location.user_format(rolf, params[:location][:display_name])
    params[:id] = loc.id
    put_requires_login(:update, params)
    assert_redirected_to(location_path(loc.id))
    assert_equal(contrib, rolf.reload.contribution)

    # Should have created a new version of location only.
    assert_equal(count + 1, Location::Version.count)
    assert_equal(count2, LocationDescription::Version.count)

    # Should now look like Barton Flats.
    loc = Location.find(loc.id)
    new_params = update_params_from_loc(loc)
    assert_not_equal(new_params, old_params)

    # It and the RssLog should have been updated
    assert_not_equal(updated_at, loc.updated_at)
    assert_not_equal(log_updated_at, loc.rss_log.updated_at)

    # Only compare the keys that are in both.
    bfp = barton_flats_params
    key_count = 0
    bfp.each_key do |k|
      if new_params[k]
        key_count += 1
        assert_equal(new_params[k], bfp[k])
      end
    end
    assert(key_count.positive?) # Make sure something was compared.

    # Rolf was already author, Mary doesn't become editor because
    # there was no change.
    assert_user_arrays_equal([rolf], loc.description.authors)
    assert_user_arrays_equal([], loc.description.editors)
  end

  # Test update for north > 90.
  def test_update_location_errors
    params = update_params_from_loc(locations(:albion))
    params[:location][:north] = 100
    update_location_error(params)
  end

  # Test update with a dubious location name
  def test_update_location_name_errors
    params = update_params_from_loc(locations(:albion))
    params[:location][:display_name] = "Somewhere Dubious"
    update_location_error(params)
  end

  def test_update_location_screwy_names
    login("dick")
    loc = locations(:burbank)
    params = update_params_from_loc(loc)

    params[:location][:display_name] = ""
    put(:update, params: params)
    assert_response(:success) # means failure!

    params[:location][:display_name] = " Strip  This,  Maine,  USA "
    put(:update, params: params)
    assert_response(:redirect)
    assert_equal("Strip This, Maine, USA", loc.reload.display_name)
  end

  def test_update_location_with_scientific_names
    rolf.location_format = "scientific"
    rolf.save
    login("rolf")
    loc = locations(:burbank)
    normal_name = loc.name
    scientific_name = loc.display_name
    assert_not_equal(normal_name, scientific_name)
    get(:edit, params: { id: loc.id })
    assert_input_value(:location_display_name, scientific_name)

    new_normal_name = "Undefined Town, California, USA"
    new_scientific_name = "USA, California, Undefined Town"
    params = update_params_from_loc(loc)
    params[:location][:display_name] = new_normal_name
    put(:update, params: params)
    assert_response(:success) # means failure

    params[:location][:display_name] = new_scientific_name
    put(:update, params: params)
    assert_response(:redirect) # means success
    loc.reload
    assert_equal(new_normal_name, loc.name)
    assert_equal(new_scientific_name, loc.display_name)
  end

  def test_nontrivial_change
    login("rolf")
    loc = locations(:burbank)
    assert_equal("Burbank, California, USA", loc.display_name)
    trivial_change = "Furbank, Kalifornia, USA"
    nontrivial_change = "Asheville, North Carolina, USA"
    params = update_params_from_loc(loc)

    params[:location][:display_name] = trivial_change
    put(:update, params: params)
    assert_no_emails

    params[:location][:display_name] = nontrivial_change
    put(:update, params: params)
    assert_email_generated
  end

  # Burbank has observations so it stays.
  def test_update_location_user_merge
    to_go = locations(:burbank)
    to_stay = locations(:albion)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name
    loc_count = Location.count
    desc_count = LocationDescription.count
    past_loc_count = Location::Version.count
    past_desc_count = LocationDescription::Version.count
    herbarium = herbaria(:burbank_herbarium)

    put_requires_login(:update, params)

    assert_redirected_to(location_path(to_go.id))
    assert_equal(loc_count - 1, Location.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_loc_count - 1, Location::Version.count)
    assert_equal(past_desc_count, LocationDescription::Version.count)
    assert_equal(10 - @new_pts, rolf.reload.contribution)
  end

  def test_update_location_admin_merge
    to_go = locations(:albion)
    to_stay = locations(:burbank)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name

    loc_count = Location.count
    desc_count = LocationDescription.count
    past_loc_count = Location::Version.count
    past_desc_count = LocationDescription::Version.count
    past_locs_to_go = to_go.versions.length
    past_descs_to_go = 0

    make_admin("rolf")
    put(:update, params: params)

    # assert_template("locations/show")
    assert_redirected_to(location_path(to_stay.id))
    assert_equal(loc_count - 1, Location.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_loc_count + 1 - past_locs_to_go, Location::Version.count)
    assert_equal(past_desc_count - past_descs_to_go,
                 LocationDescription::Version.count)
  end

  def test_post_edit_location_locked
    location = locations(:unknown_location)
    params = {
      id: location.id,
      location: {
        locked: "",
        display_name: "My Back Yard, Fresno, California, USA",
        north: "31",
        south: "30",
        east: "-118",
        west: "-119",
        high: "30",
        low: "10",
        notes: "new notes"
      }
    }

    login("rolf")
    get(:edit, params: { id: location.id })
    assert_select("input[type=checkbox]#location_locked", count: 0)
    assert_select("input[type=text]#location_display_name", count: 0)
    assert_select("input[type=text]#location_north", count: 0)
    assert_select("input[type=text]#location_south", count: 0)
    assert_select("input[type=text]#location_east", count: 0)
    assert_select("input[type=text]#location_west", count: 0)
    assert_select("input[type=text]#location_high", count: 0)
    assert_select("input[type=text]#location_low", count: 0)

    put(:update, params: params)
    location.reload
    assert_true(location.locked)
    assert_equal("Earth", location.name)
    assert_equal(90, location.north)
    assert_equal(-90, location.south)
    assert_equal(180, location.east)
    assert_equal(-180, location.west)
    assert_nil(location.high)
    assert_nil(location.low)
    assert_equal("new notes", location.notes)

    make_admin("mary")
    get(:edit, params: { id: location.id })
    assert_select("input[type=checkbox]#location_locked", count: 1)
    assert_select("input[type=text]#location_display_name", count: 1)
    assert_select("input[type=text]#location_north", count: 1)
    assert_select("input[type=text]#location_south", count: 1)
    assert_select("input[type=text]#location_east", count: 1)
    assert_select("input[type=text]#location_west", count: 1)
    assert_select("input[type=text]#location_high", count: 1)
    assert_select("input[type=text]#location_low", count: 1)

    put(:update, params: params)
    location.reload
    assert_false(location.locked)
    assert_equal("My Back Yard, Fresno, California, USA", location.name)
    assert_equal(31, location.north)
    assert_equal(30, location.south)
    assert_equal(-118, location.east)
    assert_equal(-119, location.west)
    assert_equal(30, location.high)
    assert_equal(10, location.low)
  end

  def test_update_location_scientific_name
    loc = Location.first
    params = {
      id: loc.id,
      location: {}
    }

    login("rolf")
    assert_equal("postal", rolf.location_format)
    postal_name = "Missoula, Montana, USA"
    scientific_name = "USA, Montana, Missoula"
    params[:location][:display_name] = postal_name
    put(:update, params: params)
    assert_flash_success
    assert_response(:redirect)
    loc.reload
    assert_equal(postal_name, loc.name)
    assert_equal(scientific_name, loc.scientific_name)

    login("roy")
    assert_equal("scientific", roy.location_format)
    postal_name = "Santa Fe, New Mexico, USA"
    scientific_name = "USA, New Mexico, Santa Fe"
    params[:location][:display_name] = scientific_name
    put(:update, params: params)
    assert_flash_success
    assert_response(:redirect)
    loc.reload
    assert_equal(postal_name, loc.name)
    assert_equal(scientific_name, loc.scientific_name)
  end

  ##############################################################################
  #
  #    DESTROY

  def test_destroy_location
    location = locations(:california)
    params = { id: location.id }

    login(location.user.login)
    delete(:destroy, params: params)
    assert(Location.exists?(location.id),
           "Location should be destroyable only if user is in admin mode")

    make_admin
    delete(:destroy, params: params)
    assert_redirected_to(locations_path)
    assert_not(Location.exists?(location.id),
               "Failed to destroy Location #{location.id}, '#{location.name}'")
  end

  def named_obs_query(name)
    Query.lookup(:Observation, :pattern_search, pattern: name, by: :name)
  end

  def test_coercing_sorted_observation_query_into_location_query
    @controller.
      coerce_query_for_undefined_locations(named_obs_query("Pasadena").
      coerce(:Location))
  end
end
