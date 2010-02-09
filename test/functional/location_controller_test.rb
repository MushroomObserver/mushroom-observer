require File.dirname(__FILE__) + '/../boot'

class LocationControllerTest < ControllerTestCase

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
      }
    }
  end

  # A location that isn't in fixtures.
  def barton_flats_params
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

  # Post a change that fails -- make sure no new version created.
  def location_error(page, params)
    loc_count = Location.count
    past_loc_count = Location::PastLocation.count
    post_requires_login(page, params)
    assert_response(page.to_s)
    assert_equal(loc_count, Location.count)
    assert_equal(past_loc_count, Location::PastLocation.count)
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

  def test_author_request
    requires_login(:author_request, :id => 1)
    assert_response('author_request')
  end

  def test_review_authors
    # Make sure it lets Rolf and only Rolf see this page.
    assert(!@mary.in_group('reviewers'))
    assert(@rolf.in_group('reviewers'))
    requires_user(:review_authors, :show_location, :id => 1)
    assert_response('review_authors')

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(@rolf)
    @rolf.reload
    assert(!@rolf.in_group('reviewers'))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, :id => 1)
    assert_response(:action => :show_location, :id => 1)

    # Make Rolf an author.
    albion = locations(:albion)
    albion.add_author(@rolf)
    albion.save
    albion.reload
    assert_equal([@rolf.login], albion.authors.map(&:login).sort)

    # Rolf should be able to do it now.
    get(:review_authors, :id => 1)
    assert_response('review_authors')

    # Rolf giveth with one hand...
    post(:review_authors, :id => 1, :add => @mary.id)
    assert_response('review_authors')
    albion.reload
    assert_equal([@mary.login, @rolf.login], albion.authors.map(&:login).sort)

    # ...and taketh with the other.
    post(:review_authors, :id => 1, :remove => @mary.id)
    assert_response('review_authors')
    albion.reload
    assert_equal([@rolf.login], albion.authors.map(&:login).sort)
  end

  def test_create_location
    requires_login(:create_location)
    assert_form_action(:action => 'create_location')
  end

  # Test a simple location creation.
  def test_construct_location_simple
    count = Location.find(:all).length
    params = barton_flats_params
    display_name = params[:where]
    post_requires_login(:create_location, params)
    assert_response(:action => :show_location)
    assert_equal(count + 1, Location.find(:all).length)
    assert_equal(20, @rolf.reload.contribution)
    loc = assigns(:location)
    assert_equal(display_name, loc.display_name) # Make sure it's the right Location
    loc = Location.find_by_display_name(display_name)
    assert_equal([@rolf.login], loc.authors.map(&:login).sort)
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
    params = { "id" => loc.id.to_s }
    requires_login(:edit_location, params)
    assert_form_action(:action => 'edit_location')
  end

  def test_update_location
    count = Location::PastLocation.find(:all).length
    assert_equal(10, @rolf.reload.contribution)

    # Turn Albion into Barton Flats
    loc = locations(:albion)
    loc.add_author(@mary)
    old_north = loc.north
    old_params = update_params_from_loc(loc)
    params = barton_flats_params
    params[:id] = loc.id
    post_requires_login(:edit_location, params)
    assert_response(:action => :show_location)
    assert_equal(15, @rolf.reload.contribution)

    # Should have created a PastLocation
    assert_equal(count + 1, Location::PastLocation.find(:all).length)

    # Should now look like Barton Flats
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

    assert_equal([@mary.login], loc.authors.map(&:login).sort)
  end

  # Test update for north > 90.
  def test_update_location_errors
    params = update_params_from_loc(locations(:albion))
    params[:location][:north] = 100
    update_location_error(params)
  end

  def test_update_location_user_merge
    to_go = locations(:burbank)
    to_stay = locations(:albion)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name
    loc_count = Location.count
    past_loc_count = Location::PastLocation.count
    post_requires_login(:edit_location, params)
    assert_response(:action => :show_location)
    assert_equal(loc_count, Location.count)
    assert_equal(past_loc_count, Location::PastLocation.count)
    assert_equal(10, @rolf.reload.contribution)
  end

  def test_update_location_admin_merge
    to_go = locations(:albion)
    to_stay = locations(:burbank)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name

    loc_count = Location.count
    past_loc_count = Location::PastLocation.count
    past_locs_to_go = to_go.versions.length

    make_admin('rolf')
    post_with_dump(:edit_location, params)
    assert_response(:action => "show_location")

    assert_equal(loc_count - 1, Location.count)
    assert_equal(past_loc_count - past_locs_to_go, Location::PastLocation.count)
  end

  def test_list_merge_options
    albion = locations(:albion)
    # Full match with albion
    requires_login(:list_merge_options, :where => albion.display_name)
    assert_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, :where => 'Albion, CA')
    assert_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, :where => 'Albion Field Station, CA')
    assert_equal([albion], assigns(:matches))

    # Shouldn't match anything.
    requires_login(:list_merge_options, :where => 'Somewhere out there')
    assert_equal(nil, assigns(:matches))
  end

  def test_add_to_location
    User.current = @rolf
    albion = locations(:albion)
    obs = Observation.create(
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
    Interest.new(:object => albion, :user => @rolf, :state => true).save
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
    Interest.new(:object => albion, :user => @rolf, :state => false).save
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
