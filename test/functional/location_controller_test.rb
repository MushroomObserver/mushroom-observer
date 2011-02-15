# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class LocationControllerTest < FunctionalTestCase

  def setup
    @new_pts  = 10
    @chg_pts  = 5
    @auth_pts = 50
    @edit_pts = 5
  end

  # Init params based on existing location.
  def update_params_from_loc(loc)
    { :id => loc.id,
      :location => {
        :display_name => loc.display_name,
        :north => loc.north,
        :west => loc.west,
        :east => loc.east,
        :south => loc.south,
        :high => loc.high,
        :low => loc.low,
        :notes => loc.notes
      },
    }
  end

  # A location that isn't in fixtures.
  def barton_flats_params
    name = "Barton Flats, California, USA"
    {
      :display_name => name,
      :location => {
        :display_name => name,
        :north => 34.1865,
        :west => -116.924,
        :east => -116.88,
        :south => 34.1571,
        :high => 2000.0,
        :low => 1600.0,
        :notes => "This is now Barton Flats",
      },
    }
  end

  # Post a change that fails -- make sure no new version created.
  def location_error(page, params)
    loc_count = Location.count
    past_loc_count = Location::Version.count
    desc_count = LocationDescription.count
    past_desc_count = LocationDescription::Version.count
    post_requires_login(page, params)
    assert_response(page.to_s)
    assert_equal(loc_count, Location.count)
    assert_equal(past_loc_count, Location::Version.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_desc_count, LocationDescription::Version.count)
  end

  # Post "create_location" with errors.
  def construct_location_error(params)
    location_error(:create_location, params)
  end

  # Post "update_location" with errors.
  def update_location_error(params)
    location_error(:edit_location, params)
  end

################################################################################

  def test_show_location
    get_with_dump(:show_location, :id => 1)
    assert_response('show_location')
  end

  def test_show_past_location
    get_with_dump(:show_past_location, :id => 1)
    assert_response('show_past_location')
  end

  def test_list_locations
    get_with_dump(:list_locations)
    assert_response('list_locations')
  end

  def test_locations_by_user
    get_with_dump(:locations_by_user, :id => 1)
    assert_response('list_locations')
  end

  def test_locations_by_editor
    get_with_dump(:locations_by_editor, :id => 1)
    assert_response('list_locations')
  end

  def test_list_location_descriptions
    login('mary')
    Location.find(2).description = LocationDescription.create!(:location_id => 2)
    get_with_dump(:list_location_descriptions)
    assert_response('list_location_descriptions')
  end

  def test_location_descriptions_by_author
    descs = LocationDescription.all
    assert_equal(1, descs.length)
    get_with_dump(:location_descriptions_by_author, :id => 1)
    assert_response(:action => 'show_location_description', :id => descs.first.id)
  end

  def test_location_descriptions_by_editor
    get_with_dump(:location_descriptions_by_editor, :id => 1)
    assert_response('list_location_descriptions')
  end

  def test_create_location
    requires_login(:create_location)
    assert_form_action(:action => 'create_location', :set_user => 0)
  end

  # Test a simple location creation.
  def test_construct_location_simple
    count = Location.count
    params = barton_flats_params
    display_name = params[:display_name]
    post_requires_login(:create_location, params)
    assert_response(:action => :show_location)
    assert_equal(count + 1, Location.count)
    assert_equal(10 + @new_pts, @rolf.reload.contribution)
    loc = assigns(:location)
    assert_equal(display_name, loc.display_name) # Make sure it's the right Location
    loc = Location.search_by_name(display_name)
    assert_nil(loc.description)
  end

  def test_construct_location_name_errors
    # Test creating a location with a dubious location name
    params = barton_flats_params
    params[:location][:display_name] = "Somewhere Dubious"
    construct_location_error(params)
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

  def test_edit_location
    loc = locations(:albion)
    params = { :id => loc.id.to_s }
    requires_login(:edit_location, params)
    assert_form_action(:action => 'edit_location')
  end

  def test_update_location
    count = Location::Version.count
    count2 = LocationDescription::Version.count
    assert_equal(10, @rolf.reload.contribution)

    # Turn Albion into Barton Flats.
    loc = locations(:albion)
    old_north = loc.north
    old_params = update_params_from_loc(loc)
    params = barton_flats_params
    params[:location][:display_name] = Location.user_name(@rolf, params[:location][:display_name])
    params[:id] = loc.id
    post_requires_login(:edit_location, params)
    assert_response(:action => :show_location)
    assert_equal(10, @rolf.reload.contribution)

    # Should have created a new version of location only.
    assert_equal(count + 1, Location::Version.count)
    assert_equal(count2, LocationDescription::Version.count)

    # Should now look like Barton Flats.
    loc = Location.find(loc.id)
    new_params = update_params_from_loc(loc)
    assert_not_equal(new_params, old_params)

    # Only compare the keys that are in both.
    bfp = barton_flats_params
    key_count = 0
    for k in bfp.keys
      if new_params[k]
        key_count += 1
        assert_equal(new_params[k], bfp[k])
      end
    end
    assert(key_count > 0) # Make sure something was compared.

    # Rolf was already author, Mary doesn't become editor because
    # there was no change.
    assert_user_list_equal([@rolf], loc.description.authors)
    assert_user_list_equal([], loc.description.editors)
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
    post_requires_login(:edit_location, params)
    assert_response(:action => :show_location)
    assert_equal(loc_count-1, Location.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_loc_count-1, Location::Version.count)
    assert_equal(past_desc_count, LocationDescription::Version.count)
    assert_equal(10 - @new_pts, @rolf.reload.contribution)
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

    make_admin('rolf')
    post_with_dump(:edit_location, params)
    assert_response(:action => "show_location")

    assert_equal(loc_count - 1, Location.count)
    assert_equal(desc_count, LocationDescription.count)
    assert_equal(past_loc_count+1 - past_locs_to_go, Location::Version.count)
    assert_equal(past_desc_count - past_descs_to_go, LocationDescription::Version.count)
  end

  def test_list_merge_options
    albion = locations(:albion)

    # Full match with albion.
    requires_login(:list_merge_options, :where => albion.display_name)
    assert_obj_list_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, :where => 'Albion, CA')
    assert_obj_list_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, :where => 'Albion Field Station, CA')
    assert_obj_list_equal([albion], assigns(:matches))

    # Shouldn't match anything.
    requires_login(:list_merge_options, :where => 'Somewhere out there')
    assert_equal(nil, assigns(:matches))
  end

  def test_add_to_location
    User.current = @rolf
    albion = locations(:albion)
    obs = Observation.create!(
      :when  => Time.now,
      :where => (where = 'undefined location'),
      :notes => 'new observation'
    )
    assert_equal(obs.location, nil)
    where = obs.where
    params = {
      :where    => where,
      :location => albion.id
    }
    requires_login(:add_to_location, params)
    assert_response(:action => :list_locations)
    assert_not_nil(obs.reload.location)
    assert_equal(albion, obs.location)
  end

  def test_add_to_location_scientific
    login('roy')
    albion = locations(:albion)
    obs = Observation.create!(
      :when  => Time.now,
      :where => (where = 'Albion, Mendocino Co., California, USA'),
      :notes => 'new observation'
    )
    assert_equal(obs.location, nil)
    assert_equal(:scientific, @roy.location_format)
    params = {
      :where    => where,
      :location => albion.id
    }
    requires_login(:add_to_location, params, 'roy')
    assert_response(:action => :list_locations)
    assert_not_nil(obs.reload.location)
    assert_equal(albion, obs.location)
  end

  def test_map_locations
    # test_map_locations - map everything
    get_with_dump(:map_locations)
    assert_response('map_locations')

    # test_map_locations_empty - map nothing
    get_with_dump(:map_locations, :pattern => 'Never Never Land')
    assert_response('map_locations')

    # test_map_locations_some - map something
    get_with_dump(:map_locations, :pattern => 'California')
    assert_response('map_locations')
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_location
    # No interest in this location yet.
    albion = locations(:albion)
    login('rolf')
    get(:show_location, :id => albion.id)
    assert_response('show_location')
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => 1
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.new(:target => albion, :user => @rolf, :state => true).save
    get(:show_location, :id => albion.id)
    assert_response('show_location')
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.find_all_by_user_id(@rolf.id).last.destroy
    Interest.new(:target => albion, :user => @rolf, :state => false).save
    get(:show_location, :id => albion.id)
    assert_response('show_location')
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Location', :id => albion.id, :state => 1
    )
  end
end
