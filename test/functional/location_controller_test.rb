require File.dirname(__FILE__) + '/../test_helper'
require 'location_controller'

# Re-raise errors caught by the controller.
class LocationController; def rescue_action(e) raise e end; end

class LocationControllerTest < Test::Unit::TestCase
  fixtures :locations
  fixtures :past_locations
  fixtures :users
  fixtures :observations

  def setup
    @controller = LocationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_where_search
    get_with_dump :where_search
    assert_redirected_to(:controller => "location", :action => "list_place_names")
  end

  def test_where_search_for_something
    params = {
      :where => 'Burbank'
    }
    get_with_dump(:where_search, params)
    assert_redirected_to(:controller => "observer", :action => "location_search")
  end

  def test_show_location
    get_with_dump :show_location, :id => 1
    assert_response :success
    assert_template 'show_location'
  end

  def test_show_past_location
    get_with_dump :show_past_location, :id => 1
    assert_response :success
    assert_template 'show_past_location'
  end

  def test_list_place_names
    get_with_dump :list_place_names
    assert_response :success
    assert_template 'list_place_names'
  end

  def test_create_location
    requires_login :create_location
    assert_form_action :action => 'create_location'
  end

  # A location that isn't in locations.yml
  def barton_flats_params()
    display_name = "Barton Flats, San Bernardino Co., California, USA"
    {
      :where => display_name,
      :location => {
        :display_name => display_name,
        :north => 34.1865,
        :west => -116.924,
        :east => -116.88,
        :south => 34.1571,
        :high => 2000.0,
        :low => 1600.0,
        :notes => "A popular spring time collecting area for the Los Angeles Mycological Society."
      }
    }
  end

  def test_construct_location_simple
    # Test a simple location creation
    count = Location.find(:all).length
    params = barton_flats_params
    display_name = params[:where]
    post_requires_login(:create_location, params, false)
    assert_redirected_to(:controller => "location", :action => "show_location")
    assert_equal(count + 1, Location.find(:all).length)
    loc = assigns(:location)
    assert_equal(display_name, loc.display_name) # Make sure it's the right Location
  end

  def location_error(page, params)
    loc_count = Location.find(:all).length
    past_loc_count = PastLocation.find(:all).length
    post_requires_login(page, params, false)
    assert_response :success
    assert_template(page.to_s) # Really indicates an error

    assert_equal(loc_count, Location.find(:all).length)
    assert_equal(past_loc_count, PastLocation.find(:all).length)
  end

  def construct_location_error(params)
    location_error(:create_location, params)
  end

  # Test for north > 90
  def test_construct_location_north_error
    params = barton_flats_params
    params[:location][:north] = 100
    construct_location_error(params)
  end

  # Test for south < -90
  def test_construct_location_south_error
    params = barton_flats_params
    params[:location][:south] = -100
    construct_location_error(params)
  end

  # Test for north < south
  def test_construct_location_north_south_error
    params = barton_flats_params
    north = params[:location][:north]
    params[:location][:north] = params[:location][:south]
    params[:location][:south] = north
    construct_location_error(params)
  end

  # Test for west < -180
  def test_construct_location_south_error
    params = barton_flats_params
    params[:location][:west] = -200
    construct_location_error(params)
  end

  # Test for west > 180
  def test_construct_location_south_error
    params = barton_flats_params
    params[:location][:west] = 200
    construct_location_error(params)
  end

  # Test for east < -180
  def test_construct_location_south_error
    params = barton_flats_params
    params[:location][:east] = -200
    construct_location_error(params)
  end

  # Test for east > 180
  def test_construct_location_south_error
    params = barton_flats_params
    params[:location][:east] = 200
    construct_location_error(params)
  end

  # Test for high < low
  def test_construct_location_high_low_error
    params = barton_flats_params
    high = params[:location][:high]
    params[:location][:high] = params[:location][:low]
    params[:location][:low] = high
    construct_location_error(params)
  end

  def test_edit_location
    loc = @albion
    params = { "id" => loc.id.to_s }
    requires_login(:edit_location, params)
    assert_form_action :action => 'edit_location'
  end

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
      }
    }
  end

  def test_update_location
    count = PastLocation.find(:all).length

    # Turn Albion into Barton Flats
    loc = @albion
    old_north = loc.north
    old_params = update_params_from_loc(loc)
    params = barton_flats_params
    params[:id] = loc.id
    post_requires_login(:edit_location, params, false)
    assert_redirected_to(:controller => "location", :action => "show_location")

    # Should have created a PastLocation
    assert_equal(count + 1, PastLocation.find(:all).length)

    # Shoul now look like Barton Flats
    loc = Location.find(loc.id)
    new_params = update_params_from_loc(loc)
    assert_not_equal(new_params, old_params)

    # Only compare the keys that are in both
    bfp = barton_flats_params
    key_count = 0
    for k in bfp.keys
      if new_params[k]
        key_count += 1
        assert_equal(new_params[k], bfp[k])
      end
    end
    assert(key_count > 0) # Make sure something was compared
  end


  def update_location_error(params)
    location_error(:edit_location, params)
  end

  # Test for north > 90
  def test_construct_location_north_error
    params = update_params_from_loc(@albion)
    params[:location][:north] = 100
    update_location_error(params)
  end

  def test_update_location_user_merge
    to_go = @burbank
    to_stay = @albion
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name
    loc_count = Location.find(:all).length
    past_loc_count = PastLocation.find(:all).length
    post_requires_login(:edit_location, params, false)
    assert_redirected_to(:controller => "location", :action => "show_location")
    assert(loc_count == Location.find(:all).length)
    assert(past_loc_count == PastLocation.find(:all).length)
  end

  def test_update_location_admin_merge
    to_go = @albion
    to_stay = @burbank
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name

    loc_count = Location.find(:all).length
    past_loc_count = PastLocation.find(:all).length
    past_locs_to_go = to_go.past_locations.length

    # Make rolf the admin.  Unit tests don't like a yaml user with id=0
    user = User.authenticate('rolf', 'testpassword')
    assert(user)
    user.id = 0
    @request.session['user'] = user

    post_with_dump(:edit_location, params)
    assert_redirected_to(:controller => "location", :action => "show_location")

    assert_equal(loc_count - 1, Location.find(:all).length)
    assert_equal(past_loc_count - past_locs_to_go, PastLocation.find(:all).length)
  end

  def test_list_merge_options_full
    requires_login(:list_merge_options, { :where => @albion.display_name }) # Full match with @albion
    assert_equal(assigns(:matches), [@albion])
  end

  def test_list_merge_options_comma
    requires_login(:list_merge_options, { :where => 'Albion, CA' }) # Should match against @albion
    assert_equal(assigns(:matches), [@albion])
  end

  def test_list_merge_options_space
    requires_login(:list_merge_options, { :where => 'Albion Field Station, CA' }) # Should match against @albion
    assert_equal(assigns(:matches), [@albion])
  end

  def test_list_merge_options_no_match
    requires_login(:list_merge_options, { :where => 'Somewhere out there' }) # Shouldn't match anything
    assert_equal(nil, assigns(:matches))
  end

  def test_add_to_location
    loc = @albion
    obs = @strobilurus_diminutivus_obs
    assert_equal(obs.location, nil)
    where = obs.where
    params = {
      :where => where,
      :location => loc.id
    }
    requires_login(:add_to_location, params, false) # Full match with @albion
    assert_redirected_to(:controller => "location", :action => 'list_place_names')
    obs = Observation.find(obs.id) # Reload
    assert_not_equal(obs.location, nil)
    assert_equal(obs.location, @albion)
  end

  # test_map_locations - map everything
  def test_map_locations
    get_with_dump :map_locations
    assert_response :success
    assert_template 'map_locations'
  end

  # test_map_locations_empty - map nothing
  def test_map_locations_empty
    get_with_dump :map_locations, :pattern => 'Never Never Land'
    assert_response :success
    assert_template 'map_locations'
  end

  # test_map_locations_some - map something
  def test_map_locations_some
    get_with_dump :map_locations, :pattern => 'California'
    assert_response :success
    assert_template 'map_locations'
  end
end
