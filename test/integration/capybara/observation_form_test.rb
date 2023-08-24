# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < CapybaraIntegrationTestCase
  # Uncomment this to try running tests with firefox_headless browser
  # def setup
  #   super
  #   Capybara.current_driver = :firefox_headless
  # end

  def test_create_minimal_observation
    rolf = users("rolf")
    login!(rolf)

    click_on("Create Observation")
    assert_selector("body.observations__new")

    within("#observation_form") do
      assert_select("observation_when_1i", text: Time.zone.today.year.to_s)
      assert_select("observation_when_2i", text: Time.zone.today.strftime("%B"))
      assert_select("observation_when_3i",
                    text: Time.zone.today.strftime("%d").to_i)
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
      fill_in("naming_name", with: "Elfin saddle")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_flash_warning
    assert_flash_text(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#name_messages", text: "MO does not recognize the name")

    within("#observation_form") do
      fill_in("naming_name", with: "Coprinus comatus")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end
  end

  PASADENA_EXTENTS = {
    north: 34.251905,
    south: 34.1192,
    east: -118.065479,
    west: -118.198139
  }.freeze

  def test_post_edit_and_destroy_with_details_and_location
    setup_image_dirs # in general_extensions
    open_create_observation_form
    submit_observation_form_with_errors
    submit_observation_form_without_errors
    submit_location_form_with_errors
    submit_location_form_without_errors
    open_edit_observation_form
    submit_observation_form_with_changes
    make_sure_observation_is_in_log_index(obs = Observation.last)
    visit(observation_path(obs.id))
    destroy_observation
    make_sure_observation_is_not_in_log_index(obs)
  end

  def open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.login__new")
    login!(katrina)
    assert_selector("body.observations__new")
    assert_form_has_correct_values(create_observation_form_defaults,
                                   "#observation_form")
  end

  def submit_observation_form_with_errors
    submit_form_with_changes(create_observation_form_first_changes,
                             "#observation_form")
    assert_selector("body.observations__create")
    assert_has_location_warning(/Unknown country/)
    assert_form_has_correct_values(
      create_observation_form_values_after_first_changes,
      "#observation_form"
    )
  end

  def submit_observation_form_without_errors
    submit_form_with_changes(create_observation_form_second_changes,
                             "#observation_form")
    assert_flash_for_create_observation
    assert_selector("body.locations__new")
    assert_new_observation_is_correct(expected_values_after_create)
    assert_form_has_correct_values(create_location_form_defaults,
                                   "#location_form")
  end

  def submit_location_form_with_errors
    submit_form_with_changes(create_location_form_first_changes,
                             "#location_form")
    assert_selector("body.locations__create")
    assert_has_location_warning(/Contains unexpected character/)
    assert_form_has_correct_values(
      create_location_form_values_after_first_changes,
      "#location_form"
    )
  end

  def submit_location_form_without_errors
    submit_form_with_changes(create_location_form_second_changes,
                             "#location_form")
    assert_flash_for_create_location
    assert_selector("body.observations__show")
    assert_new_location_is_correct(expected_values_after_location)
    assert_new_observation_is_correct(expected_values_after_location)
    assert_show_observation_page_has_important_info
  end

  def open_edit_observation_form
    new_obs = Observation.last
    click_on(class: "edit_observation_link_#{new_obs.id}")
    assert_selector("body.observations__edit")
    assert_form_has_correct_values(edit_observation_form_initial_values,
                                   "#observation_form")
  end

  def submit_observation_form_with_changes
    submit_form_with_changes(edit_observation_form_changes,
                             "#observation_form")
    assert_flash_for_edit_observation
    assert_selector("body.observations__show")
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
    assert(new_obs.created_at > 1.minute.ago)
    assert(new_obs.updated_at > 1.minute.ago)
    assert_dates_equal(expected_values[:when], new_obs.when)
    assert_equal(expected_values[:is_collection_location],
                 new_obs.is_collection_location)
    assert_equal(expected_values[:notes], new_obs.notes_show_formatted.strip)
  end

  def destroy_observation
    new_obs = Observation.last
    assert_selector("body.observations__show")
    click_button(class: "destroy_observation_link_#{new_obs.id}")
    assert_flash_for_destroy_observation
    assert_selector("body.observations__index")
  end

  def make_sure_observation_is_in_log_index(obs)
    visit(activity_logs_path)
    assert_link(href: %r{/#{obs.id}?})
  end

  def make_sure_observation_is_not_in_log_index(obs)
    visit(activity_logs_path)
    assert_no_link(href: %r{/#{obs.id}?})
    assert_link(href: /activity_logs/, text: /Agaricus campestris/)
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
    assert(new_obs.created_at > 1.minute.ago)
    assert(new_obs.updated_at > 1.minute.ago)
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
    assert_obj_arrays_equal([new_img], new_obs.images)
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
    assert_text(new_obs.when.web_date)
    assert_text(new_loc.name)
    if new_obs.is_collection_location
      assert_text(:show_observation_collection_location.l)
    else
      assert_text(:show_observation_seen_at.l)
    end
    if new_obs.specimen
      assert_text(/Fungarium records/)
    else
      assert_text(/No specimen/)
    end
    assert_text(new_obs.notes_show_formatted)
    assert_text(new_img.notes)
    assert_no_link(href: "observations?where")
    assert_link(href: /#{location_path(new_loc.id)}/)
    assert_link(href: /#{image_path(new_img.id)}/)
  end

  def review_flash(patterns)
    patterns.each { |pat| assert_flash_success(pat) }
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
    assert_selector(".alert-warning", text: regex)
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
      "observation_when_1i" => { type: :select, value: local_now.year.to_s },
      "observation_when_2i" => { type: :select, # month
                                 value: local_now.strftime("%B") },
      "observation_when_3i" => { type: :select, value: local_now.day.to_s },
      "observation_place_name" => { type: :text, value: "" },
      "observation_lat" => { type: :text, value: "" },
      "observation_long" => { type: :text, value: "" },
      "observation_alt" => { type: :text, value: "" },
      "naming_name" => { type: :text, value: "" },
      "observation_is_collection_location" => { type: :check, value: true },
      "observation_specimen" => { type: :check, value: false },
      other_notes_id => { type: :text, value: "" }
    }
  end

  def create_observation_form_first_changes
    {
      "observation_when_1i" => { type: :select, value: "2010" },
      "observation_when_2i" => { type: :select, value: "March" },
      "observation_when_3i" => { type: :select, value: "14" },
      "observation_place_name" => { type: :text, # wrong order
                                    value: "USA, California, Pasadena" },
      "observation_is_collection_location" => { type: :check, value: false },
      "observation_specimen" => { type: :check, value: true },
      "collection_number_number" => { type: :text, value: "17-034a" },
      other_notes_id => { type: :text, value: "Notes for observation" }
    }
  end

  def create_observation_form_second_changes
    {
      "observation_when_1i" => { type: :select, value: "2010" },
      "observation_when_2i" => { type: :select, value: "March" },
      "observation_when_3i" => { type: :select, value: "14" },
      "observation_place_name" => { type: :text, # user's preferred order
                                    value: "Pasadena, California, USA" },
      "observation_is_collection_location" => { type: :check, value: false },
      "observation_specimen" => { type: :check, value: true },
      other_notes_id => { type: :text, value: "Notes for observation" },
      "observation_lat" => { type: :text, value: " 12deg 34.56min N " },
      "observation_long" => { type: :text, value: " 123 45 6.78 W " },
      "observation_alt" => { type: :text, value: " 56 ft. " },
      "naming_name" => { type: :text, value: " Agaricus  campestris " },
      "naming_vote_value" => { type: :select,
                               value: Vote.confidence(Vote.next_best_vote) },
      "image_0_image" => {
        type: :file,
        value: Rails.root.join("test/images/Coprinus_comatus.jpg")
      },
      "image_0_when_1i" => { type: :select, value: "2010", visible: false },
      "image_0_when_2i" => { type: :select, value: "March", visible: false },
      "image_0_when_3i" => { type: :select, value: "14", visible: false },
      "image_0_copyright_holder" => { type: :text, value: katrina.legal_name,
                                      visible: false },
      "image_0_notes" => { type: :text, value: "Notes for image" }
    }
  end

  def create_location_form_defaults
    {
      "location_display_name" => { type: :text,
                                   value: "Pasadena, California, USA" },
      "location_high" => { type: :text, value: "" },
      "location_low" => { type: :text, value: "" },
      "location_notes" => { type: :text, value: "" },
      "location_north" => { type: :text, value: PASADENA_EXTENTS[:north] },
      "location_south" => { type: :text, value: PASADENA_EXTENTS[:south] },
      "location_east" => { type: :text, value: PASADENA_EXTENTS[:east] },
      "location_west" => { type: :text, value: PASADENA_EXTENTS[:west] }
    }
  end

  def create_location_form_first_changes
    {
      # "location_display_name" => "({[;:|]}), California, USA",
      "location_display_name" => {
        type: :text,
        value: "Pasadena: Disneyland, Some Co., California, USA"
      },
      "location_high" => { type: :text, value: "8765" },
      "location_low" => { type: :text, value: "4321" },
      "location_notes" => { type: :text, value: "oops" }
    }
  end

  def create_location_form_second_changes
    {
      "location_display_name" => {
        type: :text, value: "Pasadena, Some Co., California, USA"
      },
      "location_high" => { type: :text, value: "5678" },
      "location_low" => { type: :text, value: "1234" },
      "location_notes" => { type: :text, value: "Notes for location" }
    }
  end

  def edit_observation_form_initial_values
    img_id = Image.last.id
    {
      "observation_when_1i" => { type: :select, value: "2010" },
      "observation_when_2i" => { type: :select, value: "March" },
      "observation_when_3i" => { type: :select, value: "14" },
      "observation_place_name" => {
        type: :text, value: "Pasadena, Some Co., California, USA"
      },
      "observation_lat" => { type: :text, value: "12.576" },
      "observation_long" => { type: :text, value: "-123.7519" },
      "observation_alt" => { type: :text, value: "17" },
      "observation_is_collection_location" => { type: :check, value: false },
      "observation_specimen" => { type: :check, value: true },
      other_notes_id => { type: :text, value: "Notes for observation" },
      "good_image_#{img_id}_when_1i" => { type: :select, value: "2010" },
      "good_image_#{img_id}_when_2i" => { type: :select, value: "March" },
      "good_image_#{img_id}_when_3i" => { type: :select, value: "14" },
      "good_image_#{img_id}_copyright_holder" => { type: :text,
                                                   value: katrina.legal_name },
      "good_image_#{img_id}_notes" => { type: :text, value: "Notes for image" }
    }
  end

  def edit_observation_form_changes
    img_id = Image.last.id
    {
      "observation_when_1i" => { type: :select, value: "2011" },
      "observation_when_2i" => { type: :select, value: "April" },
      "observation_when_3i" => { type: :select, value: "15" },
      "observation_lat" => { type: :text, value: "23.4567" },
      "observation_long" => { type: :text, value: "-123.4567" },
      "observation_alt" => { type: :text, value: "987m" },
      "observation_is_collection_location" => { type: :check, value: true },
      other_notes_id => { type: :text, value: "New notes for observation" },
      "good_image_#{img_id}_when_1i" => { type: :select, value: "2011" },
      "good_image_#{img_id}_when_2i" => { type: :select, value: "April" },
      "good_image_#{img_id}_when_3i" => { type: :select, value: "15" },
      "good_image_#{img_id}_notes" => { type: :text,
                                        value: "New notes for image" }
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
      notes: "Notes for observation", # string displayed in observations/show
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
      notes: "New notes for observation", # displayed in observations/show
      image_notes: "New notes for image"
    )
  end
end
