require "test_helper"

class PostObservationTest < IntegrationTestCase
  LOGIN_PAGE = "account/login".freeze
  SHOW_OBSERVATION_PAGE = "observer/show_observation".freeze
  CREATE_OBSERVATION_PAGE = "observer/create_observation".freeze
  EDIT_OBSERVATION_PAGE = "observer/edit_observation".freeze
  CREATE_LOCATION_PAGE = "location/create_location".freeze
  OBSERVATION_INDEX_PAGE = "observer/list_observations".freeze

  PASADENA_EXTENTS = {
    north: 34.251905,
    south: 34.1192,
    east: -118.065479,
    west: -118.198139
  }.freeze

  def test_post_edit_and_destroy_a_fully_detailed_observation_in_a_new_location
    setup_image_dirs
    open_create_observation_form
    submit_observation_form_with_errors
    submit_observation_form_without_errors
    submit_location_form_with_errors
    submit_location_form_without_errors
    open_edit_observation_form
    submit_observation_form_with_changes
    path = @request.fullpath
    make_sure_observation_is_in_main_index(obs = Observation.last)
    get(path)
    destroy_observation
    make_sure_observation_is_not_in_main_index(obs)
  end

  def open_create_observation_form
    get("/" + CREATE_OBSERVATION_PAGE)
    assert_template(LOGIN_PAGE)
    login!(katrina)
    assert_template(CREATE_OBSERVATION_PAGE)
    assert_form_has_correct_values(create_observation_form_defaults)
  end

  def submit_observation_form_with_errors
    submit_form_with_changes(create_observation_form_first_changes)
    assert_template(CREATE_OBSERVATION_PAGE)
    assert_has_location_warning(/Unknown country/)
    assert_form_has_correct_values(
      create_observation_form_values_after_first_changes
    )
  end

  def submit_observation_form_without_errors
    File.stub(:rename, false) do
      submit_form_with_changes(create_observation_form_second_changes)
    end
    assert_flash_for_create_observation
    assert_template(CREATE_LOCATION_PAGE)
    assert_new_observation_is_correct(expected_values_after_create)
    assert_form_has_correct_values(create_location_form_defaults)
  end

  def submit_location_form_with_errors
    submit_form_with_changes(create_location_form_first_changes)
    assert_template(CREATE_LOCATION_PAGE)
    assert_has_location_warning(/County may not be required/)
    assert_form_has_correct_values(
      create_location_form_values_after_first_changes
    )
  end

  def submit_location_form_without_errors
    submit_form_with_changes(create_location_form_second_changes)
    assert_flash_for_create_location
    assert_template(SHOW_OBSERVATION_PAGE)
    assert_new_location_is_correct(expected_values_after_location)
    assert_new_observation_is_correct(expected_values_after_location)
    assert_show_observation_page_has_important_info
  end

  def open_edit_observation_form
    click(label: /edit/i, href: /edit_observation/)
    assert_template(EDIT_OBSERVATION_PAGE)
    assert_form_has_correct_values(edit_observation_form_initial_values)
  end

  def submit_observation_form_with_changes
    submit_form_with_changes(edit_observation_form_changes)
    assert_flash_for_edit_observation
    assert_template(SHOW_OBSERVATION_PAGE)
    assert_edit_observation_is_correct(expected_values_after_edit)
    assert_show_observation_page_has_important_info
  end

  # Rename from new_observation to just observation ***
  def assert_edit_observation_is_correct(expected_values)
    assert_edit_observation_has_correct_data(expected_values)
    assert_observation_has_correct_location(expected_values)
    assert_observation_has_correct_name(expected_values)
    assert_observation_has_correct_image(expected_values)
  end

  def assert_edit_observation_has_correct_data(expected_values)
    new_obs = Observation.last
    assert_users_equal(expected_values[:user], new_obs.user)
    assert(new_obs.created_at > Time.zone.now - 1.minute)
    assert(new_obs.updated_at > Time.zone.now - 1.minute)
    assert_dates_equal(expected_values[:when], new_obs.when)
    assert_equal(expected_values[:is_collection_location],
                 new_obs.is_collection_location)
    assert_equal(expected_values[:notes], new_obs.notes_show_formatted.strip)
  end

  def destroy_observation
    click(label: /destroy/i, href: /destroy_observation/)
    assert_flash_for_destroy_observation
    assert_template(OBSERVATION_INDEX_PAGE)
  end

  def make_sure_observation_is_in_main_index(obs)
    open_session do
      get("/")
      assert_link_exists_beginning_with("/#{obs.id}?")
    end
  end

  def make_sure_observation_is_not_in_main_index(obs)
    open_session do
      get("/")
      assert_no_link_exists_beginning_with("/#{obs.id}?")
      assert_exists_deleted_item_log
    end
  end

  def assert_new_observation_is_correct(expected_values)
    assert_new_observation_has_correct_data(expected_values)
    assert_observation_has_correct_location(expected_values)
    assert_observation_has_correct_name(expected_values)
    assert_observation_has_correct_image(expected_values)
  end

  def assert_new_observation_has_correct_data(expected_values)
    new_obs = Observation.last
    assert_users_equal(expected_values[:user], new_obs.user)
    assert(new_obs.created_at > Time.zone.now - 1.minute)
    assert(new_obs.updated_at > Time.zone.now - 1.minute)
    # assert_dates_equal(expected_values[:when], new_obs.when)
    assert_equal(expected_values[:is_collection_location],
                 new_obs.is_collection_location)
    assert_equal(expected_values[:specimen], new_obs.specimen)
    assert_equal(expected_values[:notes], new_obs.notes_show_formatted.strip)
  end

  def assert_observation_has_correct_location(expected_values)
    new_obs = Observation.last
    if expected_values[:where]
      assert_equal(expected_values[:where], new_obs.where)
      assert_nil(new_obs.location)
    else
      assert_equal(expected_values[:location], new_obs.where)
      assert_equal(expected_values[:location], new_obs.location.display_name)
    end
    assert_gps_equal(expected_values[:lat], new_obs.lat)
    assert_gps_equal(expected_values[:long], new_obs.long)
    assert_gps_equal(expected_values[:alt], new_obs.alt)
  end

  def assert_observation_has_correct_name(expected_values)
    new_obs = Observation.last
    assert_names_equal(expected_values[:name], new_obs.name)
    assert_equal(expected_values[:vote], new_obs.owners_votes.first.value)
  end

  def assert_observation_has_correct_image(expected_values)
    new_obs = Observation.last
    new_img = Image.last
    assert_obj_list_equal([new_img], new_obs.images)
    assert_dates_equal(expected_values[:when], new_img.when)
    assert_equal(expected_values[:user].legal_name, new_img.copyright_holder)
    assert_equal(expected_values[:image_notes], new_img.notes.strip)
  end

  def assert_new_location_is_correct(expected_values)
    new_loc = Location.last
    assert_equal(expected_values[:location], new_loc.display_name)
    assert_in_delta(expected_values[:north], new_loc.north, 0.001)
    assert_in_delta(expected_values[:south], new_loc.south, 0.001)
    assert_in_delta(expected_values[:east], new_loc.east, 0.001)
    assert_in_delta(expected_values[:west], new_loc.west, 0.001)
  end

  def assert_show_observation_page_has_important_info
    new_obs = Observation.last
    new_loc = Location.last
    new_img = Image.last
    assert_match(new_obs.when.web_date, response.body)
    assert_match(new_loc.name, response.body)
    if new_obs.is_collection_location
      assert_match(:show_observation_collection_location.l, response.body)
    else
      assert_match(:show_observation_seen_at.l, response.body)
    end
    if new_obs.specimen
      assert_match(/show_herbarium_record/, response.body)
    else
      refute_match(/No specimen/, response.body)
    end
    assert_match(new_obs.notes_show_formatted, response.body)
    assert_match(new_img.notes, response.body)
    assert_no_link_exists_containing("observations_at_where")
    assert_link_exists_containing("show_location/#{new_loc.id}")
    assert_link_exists_containing("show_image/#{new_img.id}")
  end

  def review_flash(patterns)
    notice = get_last_flash
    assert_flash_success
    patterns.each { |pat| assert_match(pat, notice) }
  end

  def assert_flash_for_create_observation
    review_flash([/success/i, /created observation/i,
                  /created proposed name/i, /uploaded/i])
  end

  def assert_flash_for_create_location
    review_flash([/success/i, /created location/i])
  end

  def assert_flash_for_edit_observation
    review_flash([/success/i, /updated observation/i,
                  /updated notes on image/i])
  end

  def assert_flash_for_destroy_observation
    review_flash([/success/i, /destroyed/i])
  end

  def assert_has_location_warning(regex)
    assert_select(".alert-warning", { text: regex },
                  "Expected there to be a warning about location.")
  end

  def assert_exists_deleted_item_log
    found = false
    assert_select("a[href*=show_rss_log]") do |elems|
      found = true if elems.any? { |e| e.to_s.match(/Agaricus campestris/mi) }
    end
    assert(found,
           'Expected to find a "destroyed" rss log somewhere on the page.')
  end

  def create_observation_form_values_after_first_changes
    create_observation_form_defaults.merge(
      create_observation_form_first_changes
    )
  end

  def create_location_form_values_after_first_changes
    create_location_form_defaults.merge(create_location_form_first_changes)
  end

  def other_notes_id
    Observation.notes_part_id(Observation.other_notes_part)
  end

  def create_observation_form_defaults
    local_now = Time.zone.now.in_time_zone
    {
      "observation_when_1i" => local_now.year,
      "observation_when_2i" => local_now.month,
      "observation_when_3i" => local_now.day,
      "observation_place_name" => "",
      "observation_lat" => "",
      "observation_long" => "",
      "observation_alt" => "",
      "name_name" => "",
      "is_collection_location" => true,
      "specimen" => false,
      other_notes_id => ""
    }
  end

  def create_observation_form_first_changes
    {
      "observation_when_1i"      => 2010,
      "observation_when_2i"      => 3,
      "observation_when_3i"      => 14,
      "observation_place_name"   => "USA, California, Pasadena", # wrong order
      "is_collection_location"   => false,
      "specimen"                 => true,
      "collection_number_number" => "17-034a",
      other_notes_id             => "Notes for observation"
    }
  end

  def create_observation_form_second_changes
    {
      "observation_when_1i" => 2010,
      "observation_when_2i" => 3,
      "observation_when_3i" => 14,
      "observation_place_name" => "Pasadena, California, USA",
      "is_collection_location" => false,
      "specimen" => true,
      other_notes_id => "Notes for observation",
      "observation_lat" => " 12deg 34.56min N ",
      "observation_long" => " 123 45 6.78 W ",
      "observation_alt" => " 56 ft. ",
      "name_name" => " Agaricus  campestris ",
      "vote_value" => Vote.next_best_vote,
      "image_0_image" =>
        JpegUpload.new("#{::Rails.root}/test/images/Coprinus_comatus.jpg"),
      "image_0_when_1i" => "2010",
      "image_0_when_2i" => "3",
      "image_0_when_3i" => "14",
      "image_0_copyright_holder" => katrina.legal_name,
      "image_0_notes" => "Notes for image"
    }
  end

  def create_location_form_defaults
    {
      "location_display_name" => "Pasadena, California, USA",
      "location_high" => "",
      "location_low" => "",
      "location_notes" => "",
      "location_north" => PASADENA_EXTENTS[:north],
      "location_south" => PASADENA_EXTENTS[:south],
      "location_east" => PASADENA_EXTENTS[:east],
      "location_west" => PASADENA_EXTENTS[:west]
    }
  end

  def create_location_form_first_changes
    {
      "location_display_name" => "Pasadena, Some Co., California, USA",
      "location_high" => 8765,
      "location_low" => 4321,
      "location_notes" => "oops"
    }
  end

  def create_location_form_second_changes
    {
      "location_high" => 5678,
      "location_low" => 1234,
      "location_notes" => "Notes for location"
    }
  end

  def edit_observation_form_initial_values
    img_id = Image.last.id
    {
      "observation_when_1i" => 2010,
      "observation_when_2i" => 3,
      "observation_when_3i" => 14,
      "observation_place_name" => "Pasadena, Some Co., California, USA",
      "observation_lat" => "12.576",
      "observation_long" => "-123.7519",
      "observation_alt" => "17",
      "is_collection_location" => false,
      "specimen" => true,
      other_notes_id => "Notes for observation",
      "good_image_#{img_id}_when_1i" => 2010,
      "good_image_#{img_id}_when_2i" => 3,
      "good_image_#{img_id}_when_3i" => 14,
      "good_image_#{img_id}_copyright_holder" => katrina.legal_name,
      "good_image_#{img_id}_notes" => "Notes for image"
    }
  end

  def edit_observation_form_changes
    img_id = Image.last.id
    {
      "observation_when_1i" => "2011",
      "observation_when_2i" => "4",
      "observation_when_3i" => "15",
      "observation_lat" => "23.4567",
      "observation_long" => "-123.4567",
      "observation_alt" => "987m",
      "is_collection_location" => true,
      other_notes_id => "New notes for observation",
      "good_image_#{img_id}_when_1i" => "2011",
      "good_image_#{img_id}_when_2i" => "4",
      "good_image_#{img_id}_when_3i" => "15",
      "good_image_#{img_id}_notes" => "New notes for image"
    }
  end

  def expected_values_after_create
    {
      user: katrina,
      when: Date.parse("2010-03-14"),
      where: "Pasadena, California, USA",
      location: nil,
      lat: 12.5760,
      long: -123.7519,
      alt: 17,
      name: names(:agaricus_campestris),
      vote: Vote.next_best_vote,
      is_collection_location: false,
      specimen: true,
      notes: "Notes for observation", # string displayed in show_observation
      image_notes: "Notes for image"
    }
  end

  def expected_values_after_location
    expected_values_after_create.merge(
      where: nil,
      location: "Pasadena, Some Co., California, USA",
      north: PASADENA_EXTENTS[:north],
      south: PASADENA_EXTENTS[:south],
      east: PASADENA_EXTENTS[:east],
      west: PASADENA_EXTENTS[:west],
      high: 5678,
      low: 1234,
      location_notes: "Notes for location"
    )
  end

  def expected_values_after_edit
    expected_values_after_location.merge(
      when: Date.parse("2011-04-15"),
      lat: 23.4567,
      long: -123.4567,
      alt: 987,
      is_collection_location: true,
      specimen: false,
      notes: "New notes for observation", # string displayed in show_observation
      image_notes: "New notes for image"
    )
  end
end
