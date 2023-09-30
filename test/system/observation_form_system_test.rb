# frozen_string_literal: true

require("application_system_test_case")

class ObservationFormSystemTest < ApplicationSystemTestCase
  def notest_create_minimal_observation
    rolf = users("rolf")
    login!(rolf)

    assert_link("Create Observation")
    click_on("Create Observation")

    assert_selector("body.observations__new")
    within("#observation_form") do
      # MOAutocompleter has replaced year select with text field
      assert_field("observation_when_1i", with: Time.zone.today.year.to_s)
      assert_select("observation_when_2i", text: Time.zone.today.strftime("%B"))
      assert_select("observation_when_3i",
                    text: Time.zone.today.strftime("%d").to_i)
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
      fill_in("naming_name", with: "Elfin saddle")
      # don't wait for the autocompleter - we know it's an elfin saddle!
      send_keys(:tab)
      assert_field("naming_name", with: "Elfin saddle")
      # start typing the location...
      fill_in("observation_place_name", with: locations.first.name[0, 10])
      # wait for the autocompleter...
      assert_selector(".auto_complete")
      send_keys(:down, :tab) # cursor down to first match + select row
      assert_field("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_selector("#name_messages", text: "MO does not recognize the name")
    assert_flash_warning
    assert_flash_text(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#observation_form")
    within("#observation_form") do
      fill_in("naming_name", with: "Coprinus com")
      # wait for the autocompleter!
      assert_selector(".auto_complete")
      send_keys(:down, :tab) # cursor down to first match + select row
      # unfocus, let field validate. send_keys(:tab) doesn't work here
      find("#observation_place_name").click
      assert_field("naming_name", with: "Coprinus comatus")
      # Place name should stay filled
      assert_field("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_selector("body.observations__show")
    assert_flash_success
    assert_flash_text(/#{:runtime_observation_success.t.html_to_ascii}/)
  end

  PASADENA_EXTENTS = {
    north: 34.251905,
    south: 34.1192,
    east: -118.065479,
    west: -118.198139
  }.freeze

  def test_post_edit_and_destroy_with_details_and_location
    setup_image_dirs # in general_extensions
    local_now = Time.zone.now.in_time_zone

    # open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.login__new")
    login!(katrina)
    assert_selector("body.observations__new")

    # check new observation form defaults
    assert_field("observation_when_1i", with: local_now.year.to_s)
    assert_select("observation_when_2i", text: local_now.strftime("%B"))
    assert_select("observation_when_3i", text: local_now.day.to_s)

    assert_field("observation_place_name", text: "")
    assert_field("observation_lat", text: "")
    assert_field("observation_long", text: "")
    assert_field("observation_alt", text: "")

    assert_field("naming_name", text: "")
    assert_checked_field("observation_is_collection_location")
    assert_no_checked_field("observation_specimen")
    assert_field(other_notes_id, text: "")

    # submit_observation_form_with_errors
    fill_in("observation_when_1i", with: "2010")
    select("March", from: "observation_when_2i")
    select("14", from: "observation_when_3i")

    fill_in("observation_place_name", with: "USA, California, Pasadena")
    assert_field("observation_place_name", with: "USA, California, Pasadena")
    uncheck("observation_is_collection_location")

    check("observation_specimen")
    assert_selector("#collection_number_number")
    fill_in("collection_number_number", with: "17-034a")
    fill_in(other_notes_id, with: "Notes for observation")

    within("#observation_form") do
      click_commit
    end

    # rejected
    assert_selector("body.observations__create")
    assert_has_location_warning(/Unknown country/)

    # check form values after first changes
    assert_field("observation_when_1i", with: "2010")
    assert_select("observation_when_2i", text: "March")
    assert_select("observation_when_3i", text: "14")

    assert_field("observation_place_name", with: "USA, California, Pasadena")
    assert_field("observation_lat", text: "")
    assert_field("observation_long", text: "")
    assert_field("observation_alt", text: "")

    assert_field("naming_name", text: "")
    assert_no_checked_field("observation_is_collection_location")
    assert_checked_field("observation_specimen")
    assert_field("collection_number_number", with: "17-034a")
    assert_field(other_notes_id, with: "Notes for observation")

    # submit_observation_form_without_errors
    fill_in("observation_place_name", with: "Pasadena, Calif")
    assert_selector(".auto_complete")
    send_keys(:down, :tab) # cursor down to first match + select row
    assert_field("observation_place_name", with: "Pasadena, California, USA")
    fill_in("observation_lat", with: " 12deg 34.56min N ")
    fill_in("observation_long", with: " 123 45 6.78 W ")
    fill_in("observation_alt", with: " 56 ft. ")

    fill_in("naming_name", with: "Agaricus campe")
    assert_selector(".auto_complete ul li", text: "Agaricus campestris")
    send_keys(:down, :down, :down, :tab) # down to second match + select row
    assert_field("naming_name", with: "Agaricus campestris")
    select(Vote.confidence(Vote.next_best_vote), from: "naming_vote_value")

    # scroll_to(0, 1500)
    # Add the images separately, so we can be sure of the order. Otherwise,
    # images appear in the order each upload finishes, which is unpredictable.
    attach_file(Rails.root.join("test/images/Coprinus_comatus.jpg")) do
      find(".file-field").click
    end

    # scroll_to(0, 2400)
    assert_selector(".added_image_wrapper")
    assert_selector("#image_messages")

    first_image_wrapper = first(".added_image_wrapper")

    # Coprinus_comatus.jpg has a created_at date of November 20, 2006
    # Does not work:
    # assert_field('[id$="_temp_image_when_1i"]', with: "2006")
    # No idea why we have to do it like this, maybe value set by JS.
    within(first_image_wrapper) do
      assert_equal("2006", find('[id$="_temp_image_when_1i"]').value)
      assert_equal("11", find('[id$="_temp_image_when_2i"]').value)
      assert_equal("20", find('[id$="_temp_image_when_3i"]').value)
    end

    # "fix_date" radios: check that the first image date is available
    within("#image_date_radio_container") do
      assert_unchecked_field("20-November-2006")
    end
    # check that the chosen obs date is available
    within("#observation_date_radio_container") do
      assert_unchecked_field("14-March-2010")
      # this would be today's date in the format:
      # assert_unchecked_field(local_now.strftime("%d-%B-%Y"))
    end

    # Add a second image that's geotagged
    attach_file(Rails.root.join("test/images/geotagged.jpg")) do
      find(".file-field").click
    end

    # We should now get the option to set obs GPS
    assert_selector("#geocode_messages")

    # Be sure we have two image wrappers
    image_wrappers = all(".added_image_wrapper")
    assert_equal(image_wrappers.length, 2)
    second_image_wrapper = image_wrappers[1]

    # Check that it's the right image: this is geotagged.jpg's date
    within(second_image_wrapper) do
      assert_equal("2018", find('[id$="_temp_image_when_1i"]').value)
      assert_equal("12", find('[id$="_temp_image_when_2i"]').value)
      assert_equal("31", find('[id$="_temp_image_when_3i"]').value)
    end

    # Try removing it
    within(second_image_wrapper) { find(".remove_image_link").click }

    # Be sure we have only one image wrapper now
    image_wrappers = all(".added_image_wrapper")
    assert_equal(image_wrappers.length, 1)

    binding.break

    # Add it again
    attach_file(Rails.root.join("test/images/geotagged.jpg")) do
      find(".file-field").click
    end

    # We should now get the option to set obs GPS
    assert_selector("#geocode_messages")

    # Be sure we have two image wrappers
    image_wrappers = all(".added_image_wrapper")
    assert_equal(image_wrappers.length, 2)
    second_image_wrapper = image_wrappers[1]

    within(second_image_wrapper) do
      assert_equal("2018", find('[id$="_temp_image_when_1i"]').value)
      assert_equal("12", find('[id$="_temp_image_when_2i"]').value)
      assert_equal("31", find('[id$="_temp_image_when_3i"]').value)
    end

    # "fix_date" radios: check that the second image date is available
    within("#image_date_radio_container") do
      assert_unchecked_field("31-December-2018")
    end
    # "fix_geocode" radios: check that the gps is available
    within("#geocode_radio_container") do
      assert_unchecked_field("25.75820, -80.37313")
    end

    # Set copyright holder and image notes on both
    all('[id$="_temp_image_copyright_holder"]').each do |el|
      el.set(katrina.legal_name)
    end
    all('[id$="_temp_image_notes"]').each do |el|
      el.set("Notes for image")
    end

    # Fix divergent dates: use the obs date
    within("#observation_date_radio_container") { choose("14-March-2010") }
    click_button("fix_dates")
    assert_no_selector("image_messages")

    # Ignore divergent GPS - maybe we took the second photo in the lab?
    click_button("ignore_geocode")
    assert_no_selector("geocode_messages")

    # Be sure the dates are applied
    within(first_image_wrapper) do
      assert_equal("2010", find('[id$="_temp_image_when_1i"]').value)
      assert_equal("3", find('[id$="_temp_image_when_2i"]').value)
      assert_equal("14", find('[id$="_temp_image_when_3i"]').value)
    end
    within(second_image_wrapper) do
      assert_equal("2010", find('[id$="_temp_image_when_1i"]').value)
      assert_equal("3", find('[id$="_temp_image_when_2i"]').value)
      assert_equal("14", find('[id$="_temp_image_when_3i"]').value)
    end

    # Set the first one as the thumb_image
    within(first_image_wrapper) do
      find(".set_thumb_image").click
      assert_selector(".is_thumb_image")
    end

    binding.break

    # assert_field('observation_thumb_image_id', type: :hidden, with: ??)

    # within("#observation_form") do
    #   click_commit
    # end

    # # It should take us to create a new location
    # assert_selector("body.locations__new")
    # # The observation shoulda been created OK.
    # assert_flash_for_create_observation
    # assert_new_observation_is_correct(expected_values_after_create)

    # # check default values of location form
    # assert_field("location_display_name", with: "Pasadena, California, USA")
    # assert_field("location_high", text: "")
    # assert_field("location_low", text: "")
    # assert_field("location_notes", text: "")
    # assert_field("location_north", with: PASADENA_EXTENTS[:north])
    # assert_field("location_south", with: PASADENA_EXTENTS[:south])
    # assert_field("location_east", with: PASADENA_EXTENTS[:east])
    # assert_field("location_west", with: PASADENA_EXTENTS[:west])

    # submit_location_form_with_errors
    # submit_location_form_without_errors
    # open_edit_observation_form
    # submit_observation_form_with_changes
    # make_sure_observation_is_in_log_index(obs = Observation.last)
    # visit(observation_path(obs.id))
    # destroy_observation
    # make_sure_observation_is_not_in_log_index(obs)
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
    click_link(class: "edit_observation_link_#{new_obs.id}")
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
      "observation_when_1i" => { type: :text, value: "2010" },
      "observation_when_2i" => { type: :select, value: "March" },
      "observation_when_3i" => { type: :select, value: "14" },
      "observation_place_name" => {
        type: :autocompleter, value: "Pasadena, Some Co., California, USA"
      },
      "observation_lat" => { type: :text, value: "12.576" },
      "observation_long" => { type: :text, value: "-123.7519" },
      "observation_alt" => { type: :text, value: "17" },
      "observation_is_collection_location" => { type: :check, value: false },
      "observation_specimen" => { type: :check, value: true },
      other_notes_id => { type: :text, value: "Notes for observation" },
      "good_image_#{img_id}_when_1i" => { type: :text, value: "2010" },
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
      "observation_when_1i" => { type: :text, value: "2011" },
      "observation_when_2i" => { type: :select, value: "April" },
      "observation_when_3i" => { type: :select, value: "15" },
      "observation_lat" => { type: :text, value: "23.4567" },
      "observation_long" => { type: :text, value: "-123.4567" },
      "observation_alt" => { type: :text, value: "987m" },
      "observation_is_collection_location" => { type: :check, value: true },
      other_notes_id => { type: :text, value: "New notes for observation" },
      "good_image_#{img_id}_when_1i" => { type: :text, value: "2011" },
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
