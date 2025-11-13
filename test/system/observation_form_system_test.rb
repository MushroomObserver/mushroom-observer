# frozen_string_literal: true

require("application_system_test_case")

class ObservationFormSystemTest < ApplicationSystemTestCase
  def test_create_minimal_observation
    browser = page.driver.browser
    user = users(:zero_user)
    login!(user)

    assert_link("Create Observation")
    click_on("Create Observation")

    assert_selector("body.observations__new")
    # MOAutocompleter replaces year select with text field
    assert_field("observation_when_1i", with: Time.zone.today.year.to_s)
    assert_select("observation_when_2i", text: Time.zone.today.strftime("%B"))
    # %e is day of month, no leading zero
    assert_select("observation_when_3i", text: Time.zone.today.strftime("%e"))
    assert_selector("#observation_place_name_help",
                    text: "Albion, Mendocino Co., California", visible: :all)
    # start typing the location...
    fill_in("observation_place_name", with: locations.first.name[0, 1])
    # wait for the autocompleter...
    assert_selector(".auto_complete", wait: 6)
    browser.keyboard.type(:down, :tab) # cursor to first match + select row
    assert_field("observation_place_name", with: locations.first.name)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    fill_in("naming_name", with: "Elfin saddle")
    # don't wait for the autocompleter - we know it's an elfin saddle!
    browser.keyboard.type(:tab)
    assert_field("naming_name", with: "Elfin saddle")

    within("#observation_form") { click_commit }

    assert_flash_error(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#observation_form")

    # hard to test the internals of map, but this will pick up map load errors
    # click_button("map_location")
    # assert_selector("#observation_form_map > div > div > iframe")

    assert_field("observation_place_name", with: locations.first.name)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    assert_selector("#name_messages", text: "MO does not recognize the name")
    fill_in("naming_name", with: "Coprinus com")
    browser.keyboard.type(:tab)
    # wait for the autocompleter!
    assert_selector(".auto_complete")
    browser.keyboard.type(:down, :tab) # cursor to first match + select row
    browser.keyboard.type(:tab)
    assert_field("naming_name", with: "Coprinus comatus")
    # Place name should stay filled
    browser.keyboard.type(:tab)

    within("#observation_form") { click_commit }

    assert_selector("body.observations__show")
    assert_flash_success(/created observation/i)
  end

  def test_trying_to_create_duplicate_location_just_uses_existing_location
    setup_image_dirs # in general_extensions
    login!(katrina)

    # open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.observations__new")

    # check new observation form defaults
    assert_date_is_now
    assert_geolocation_is_empty
    last_obs = Observation.where(user_id: User.current.id).
               order(:created_at).last
    # This is currently "Falmouth, Massachusetts, USA"
    existing_loc = Location.find(last_obs.location_id)
    # We just need to check this is not the most recent location.
    assert_not_equal(Location.last.id, existing_loc.id)
    assert_field("observation_place_name", with: last_obs.where)
    assert_field("observation_location_id", with: last_obs.location_id,
                                            type: :hidden)

    # autocompleter is unconstrained
    assert_selector("[data-type='location']")
    find(id: "observation_place_name").trigger("click")
    # This should make the "create_locality" button appear.
    # It works fine in headless mode.
    assert_selector(".create-button span",
                    text: /#{:form_observations_create_locality.l}/)
    click_on(:form_observations_create_locality.l)
    assert_selector("[data-type='location_google']")
    assert_field("observation_place_name", with: last_obs.where)
    assert_field("observation_location_id", with: "", type: :hidden)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    within("#observation_form") { click_commit }

    # Observation should have saved with the existing location_id for U.P.
    assert_flash_success(/created observation/i)
    assert_selector("body.observations__show")

    obs = Observation.last
    assert_equal(existing_loc.name, obs.where)
    assert_equal(existing_loc.id, obs.location_id)
    assert_not_equal(Location.last.id, obs.location_id)
  end

  def test_autofill_location_from_geotagged_image_nothing_matches
    setup_image_dirs # in general_extensions
    login!(katrina)

    # open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.observations__new")

    # check new observation form defaults
    assert_date_is_now
    assert_geolocation_is_empty
    last_obs = Observation.recent_by_user(User.current).last
    assert_selector("#observation_place_name", wait: 6)
    assert_selector("#observation_location_id", visible: :all)
    sleep(0.5)
    assert_field("observation_place_name", with: last_obs.where)
    assert_field("observation_location_id", with: last_obs.location_id,
                                            type: :hidden)
    assert_selector("[data-type='location']")
    # Add a geotagged image
    click_attach_file("geotagged.jpg")
    sleep(0.5)

    # GPS should have been copied to the obs fields
    assert_image_gps_copied_to_obs(GEOTAGGED_EXIF)
    # Date should have been copied to the obs fields
    assert_image_date_copied_to_obs(GEOTAGGED_EXIF)
    sleep(0.5)
    # we should have the new type of location_google autocompleter now
    assert_selector(
      "[data-type='location_google'][data-autocompleter='connected']",
      wait: 10
    )
    # Place name should now have been filled by Google, no MO locations match
    assert_field("observation_place_name", with: UNIVERSITY_PARK[:name],
                                           wait: 6)
    assert_field("observation_location_id", with: "-1", type: :hidden)

    # now check that the "use_exif" button is disabled
    assert_no_button(:image_use_exif.l)
  end

  def test_autofill_location_from_geotagged_image_matching_location
    setup_image_dirs # in general_extensions
    login!(katrina)

    # Make "University Park" available as a matching location.
    university_park = Location.new(**UNIVERSITY_PARK)
    # Sanity check the lat/lng. `contains?(lat, lng)` is a Mappable::BoxMethod
    assert(university_park.contains?(GEOTAGGED_EXIF[:lat],
                                     GEOTAGGED_EXIF[:lng]))
    university_park.save!
    sleep(0.5)

    # open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.observations__new")

    # check new observation form defaults
    assert_date_is_now
    assert_geolocation_is_empty
    last_obs = Observation.recent_by_user(User.current).last
    # This is currently "Falmouth, Massachusetts, USA"
    assert_field("observation_place_name", with: last_obs.where)
    assert_field("observation_location_id", with: last_obs.location_id,
                                            type: :hidden)

    # autocompleter is unconstrained
    assert_selector("[data-type='location']")
    # Add a geotagged image
    click_attach_file("geotagged.jpg")
    sleep(2)

    # we should have a location_containing autocompleter now
    assert_selector("[data-type='location_containing']", wait: 10)
    # GPS should have been copied to the obs fields
    assert_image_gps_copied_to_obs(GEOTAGGED_EXIF)
    assert_image_date_copied_to_obs(GEOTAGGED_EXIF)
    # now check that the "use_exif" button is disabled
    assert_no_button(:image_use_exif.l)

    # Place name should have been filled.
    assert_field("observation[place_name]", with: university_park.name,
                                            wait: 6)
    assert_field("observation[location_id]", with: university_park.id,
                                             type: :hidden)

    # now clear all location fields, and the place name should clear too
    click_button(:form_observations_clear_map.l)
    # fill_in("observation_lat", with: "")
    assert_field("observation_place_name", with: "")
    # should have swapped autocompleter back to "location"
    assert_selector("[data-type='location']")

    # check that the "use_exif" button is re-enabled
    assert_button(:image_use_exif.l)
    click_button(:image_use_exif.l)
    # wait for the form to update
    assert_selector("[data-type='location_containing']")
    # GPS should have been copied to the obs fields
    assert_image_gps_copied_to_obs(GEOTAGGED_EXIF)
    assert_image_date_copied_to_obs(GEOTAGGED_EXIF)

    # Finally, the query should have gone through and the place name filled
    assert_field("observation[place_name]", with: university_park.name,
                                            wait: 6)
    assert_field("observation[location_id]", with: university_park.id,
                                             type: :hidden)
    # now check that the "use_exif" button is disabled
    assert_no_button(:image_use_exif.l)
  end

  def test_edit_observation_extracts_exif_from_saved_images
    # Test that Camera Info displays EXIF data from saved "good" images
    # when editing an observation. The server extracts EXIF from original
    # image files and passes it to FormCameraInfo via camera_info props.
    setup_image_dirs
    user = users(:katrina)
    login!(user)

    # Create observation with two geotagged images with different coordinates
    visit(new_observation_path)
    assert_selector("body.observations__new")

    # Upload first geotagged image (Miami area)
    click_attach_file("geotagged.jpg")
    assert_selector(
      ".carousel-item[data-image-status='upload']", wait: 10, visible: :all
    )

    # Upload second geotagged image (Pasadena area)
    click_attach_file("geotagged_s_pasadena.jpg")
    assert_selector(
      ".carousel-item[data-image-status='upload']",
      count: 2,
      wait: 10,
      visible: :all
    )

    # Fill in minimal required fields
    fill_in("observation_place_name", with: "California, USA")
    fill_in("naming_name", with: "Agaricus")

    # Submit to create observation
    within("#observation_form") { click_commit }
    assert_selector("body.observations__show", wait: 10)

    # Navigate to edit page
    new_obs = Observation.last
    visit(edit_observation_path(new_obs.id))
    assert_selector("body.observations__edit")

    # Find both saved geotagged images
    imgs = Image.last(2)
    miami_img = imgs.find { |img| img.original_name == "geotagged.jpg" }
    pasadena_img = imgs.find do |img|
      img.original_name == "geotagged_s_pasadena.jpg"
    end

    # Test Miami image - Click thumbnail and verify Camera Info displays EXIF
    find("#carousel_thumbnail_#{miami_img.id}").click
    sleep(0.5) # Give time for carousel transition
    miami_item = find("#carousel_item_#{miami_img.id}", visible: :all)
    within(miami_item) do
      # Camera Info should display GPS from server-extracted EXIF
      assert_selector(".exif_lat", text: GEOTAGGED_EXIF[:lat].to_s)
      assert_selector(".exif_lng", text: GEOTAGGED_EXIF[:lng].to_s)
      assert_selector(".exif_alt", text: GEOTAGGED_EXIF[:alt].to_s)
    end

    # Test Pasadena image - Click thumbnail and verify Camera Info displays EXIF
    find("#carousel_thumbnail_#{pasadena_img.id}").click
    sleep(0.5) # Give time for carousel transition
    pasadena_item = find("#carousel_item_#{pasadena_img.id}", visible: :all)
    within(pasadena_item) do
      # Camera Info should display GPS from server-extracted EXIF
      assert_selector(".exif_lat", text: SO_PASA_EXIF[:lat].to_s)
      assert_selector(".exif_lng", text: SO_PASA_EXIF[:lng].to_s)
      assert_selector(".exif_alt", text: SO_PASA_EXIF[:alt].to_s)
    end
  end

  def test_post_edit_and_destroy_with_details_and_location
    # browser = page.driver.browser
    setup_image_dirs # in general_extensions

    # open_create_observation_form
    visit(new_observation_path)
    assert_selector("body.login__new")
    login!(katrina)
    assert_selector("body.observations__new")

    # check new observation form defaults
    assert_date_is_now
    assert_geolocation_is_empty

    last_obs = Observation.recent_by_user(User.current).last
    assert_field("observation_place_name", with: last_obs.where)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    assert_field("naming_name", with: "")
    assert(last_obs.is_collection_location)
    assert_checked_field("observation_is_collection_location", visible: :all)
    assert_no_checked_field("observation_specimen", visible: :all)
    assert_field(other_notes_id, with: "", visible: :all)

    # Move to the previous step, Images/Details
    images_details = find("#observation_images_details")
    scroll_to(images_details, align: :top)

    # Add the images separately, so we can be sure of the order. Otherwise,
    # images appear in the order each upload finishes, which is unpredictable.
    click_attach_file("Coprinus_comatus.jpg")
    first_image_wrapper = first(".carousel-item[data-image-status='upload']",
                                visible: :all)
    assert_selector(".file_name", text: /Coprinus_comatus/, visible: :all)

    # Coprinus_comatus.jpg has a created_at date of November 20, 2006
    # Does not work:
    # assert_field('[id$="when_1i"]', with: "2006")
    # No idea why we have to do it like this, maybe value set by JS.
    within(first_image_wrapper) do
      assert_image_exif_available(COPRINUS_COMATUS_EXIF)
    end

    # Add a second image that's geotagged.
    click_attach_file("geotagged_s_pasadena.jpg")
    sleep(0.5)
    # Be sure we have two image wrappers. We have to wait for
    # the first one to be hidden before we can see the second one.
    image_wrappers = all(".carousel-item[data-image-status='upload']",
                         visible: :all)
    assert_equal(2, image_wrappers.length)
    # The new one is prepended, so second is "first"
    second_image_wrapper = image_wrappers[0]

    # Check that it's the right image: this is geotagged_s_pasadena.jpg's date
    within(second_image_wrapper) do
      assert_image_exif_available(SO_PASA_EXIF)
    end

    # Date should have been copied to the obs fields
    assert_image_gps_copied_to_obs(SO_PASA_EXIF)
    assert_image_date_copied_to_obs(SO_PASA_EXIF)

    # Ok, enough. By now, the carousel image should be showing the second image.
    assert_selector(
      ".carousel-item[data-image-status='upload']" \
      "[data-form-images-item='connected']",
      visible: :visible, wait: 10
    )
    # Try removing the geotagged image
    scroll_to(second_image_wrapper, align: :center)
    within(second_image_wrapper) { find(".remove_image_button").click }
    sleep(1)

    # Be sure second image has been removed
    assert_no_selector(".carousel-item[data-image-status='upload']",
                       text: "geotagged_s_pasadena.jpg", wait: 9)
    # Be sure we have only one image wrapper now
    assert_selector(".carousel-item[data-image-status='upload']",
                    visible: :all, count: 1)

    # Add geotagged_s_pasadena.jpg again
    click_attach_file("geotagged_s_pasadena.jpg")
    sleep(0.5)

    # Be sure we have two image wrappers
    second_image_wrapper = find(".carousel-item[data-image-status='upload']",
                                text: SO_PASA_EXIF[:lat].to_s)
    image_wrappers = all(".carousel-item[data-image-status='upload']",
                         visible: :all)
    assert_equal(image_wrappers.length, 2)

    within(second_image_wrapper) do
      assert_image_exif_available(SO_PASA_EXIF)
    end

    # Set copyright holder and image notes on both
    all('[id$="copyright_holder"]', visible: :all).each do |el|
      el.set(katrina.legal_name)
    end
    all('[id$="notes"]', visible: :all).each do |el|
      el.set("Notes for image")
    end

    all(".carousel-indicator").last.click
    assert_selector("#added_images", visible: :visible, wait: 3)
    assert_selector(".carousel-item[data-image-status='upload']",
                    text: /Coprinus_comatus/, wait: 3)
    # Set the first (last) one as the thumb_image
    within(first_image_wrapper) do
      thumb_button = find(".thumb_img_btn")
      scroll_to(thumb_button, align: :center)
      thumb_button.trigger("click")
      assert_text(:image_add_default.l)
      assert_no_text(:image_set_default.l)
    end

    # Override the dates from the geotagged image for this obs
    obs_when = find("#observation_when_1i")
    scroll_to(obs_when, align: :center)
    fill_in("observation_when_1i", with: "2010")
    select("August", from: "observation_when_2i")
    select("14", from: "observation_when_3i")

    # intentional error: nonexistant place name. Also, katrina's preference is
    # for postal format locations. Should not validate the country "Pasadena".
    location = find("#observation_place_name")
    scroll_to(location, align: :center)
    fill_in("observation_place_name", with: "USA, California, Pasadena")
    assert_field("observation_place_name", with: "USA, California, Pasadena")
    uncheck("observation_is_collection_location", visible: :all)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)
    sleep(1)

    specimen_section = find("#observation_specimen_section", visible: :all)
    scroll_to(specimen_section, align: :center)
    assert_field("observation_specimen")
    check("observation_specimen")
    assert_field("collection_number_number")
    fill_in("collection_number_number", with: "17-034a")
    fill_in(other_notes_id, with: "Notes for observation", visible: :all)

    # Move to the next step, Projects/Lists
    projects = find("#observation_projects")
    scroll_to(projects, align: :top)

    # Inherited project constraints maybe messing with this observation - clear
    all('[id^="project_id_"]', visible: :all).each do |project_checkbox|
      project_checkbox.trigger("click") if project_checkbox.checked?
    end
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    # submit_observation_form_with_errors
    within("#observation_form") { click_commit }

    # rejected, but images uploaded
    assert_selector("body.observations__create", wait: 12)
    assert_flash_for_images_uploaded
    assert_has_location_warning(/Unknown country/)

    # check form values after first changes
    assert_field("observation_when_1i", with: "2010")
    assert_select("observation_when_2i", text: "August")
    assert_select("observation_when_3i", text: "14")

    assert_field("observation_place_name", with: "USA, California, Pasadena")
    # GPS data should be in observation fields)
    assert_field("observation_lat", with: SO_PASA_EXIF[:lat].to_s)
    assert_field("observation_lng", with: SO_PASA_EXIF[:lng].to_s)
    # This geolocation is for Pasadena

    assert_field("naming_name", with: "", visible: :all)
    assert_no_checked_field("observation_is_collection_location", visible: :all)
    assert_checked_field("observation_specimen", visible: :all)
    assert_field("collection_number_number", with: "17-034a", visible: :all)
    assert_field(other_notes_id, with: "Notes for observation", visible: :all)

    # Submit observation form without errors
    fill_in("observation_place_name", with: "Pasadena, California, USA")
    assert_field("observation_place_name", with: "Pasadena, California, USA")
    # NOTE: EXIF extraction from "good" images works in browser but is
    # unreliablein system tests due to async image loading from test server.
    # Skip this check.
    # assert_image_gps_copied_to_obs(SO_PASA_EXIF, status: "good")

    # Carousel items are re-output with image records this time.
    all(".carousel-indicator").last.trigger("click")

    assert_selector(".carousel-item", text: SO_PASA_EXIF[:lat].to_s,
                                      visible: :all)
    second_item = find(".carousel-item", text: SO_PASA_EXIF[:lat].to_s,
                                         visible: :all)
    items = all(".carousel-item", visible: :all)
    assert_equal(items.length, 2)

    within(second_item) do
      assert_image_exif_available(SO_PASA_EXIF)
    end

    fill_in("observation_place_name", with: "south pas")
    click_on(:form_observations_create_locality.l)
    # lat/lng does not match Google's Pasadena, but does match South Pasadena
    assert_selector("[data-type='location_google']")
    find("#observation_place_name").trigger("focus")
    # assert_selector(".auto_complete", wait: 6)
    # assert_selector(".dropdown-item a[data-id='-1']",
    #                 text: SOUTH_PASADENA[:name], visible: :all, wait: 6)
    # There may be more than one of these, click the first
    # find(".dropdown-item a[data-id='-1']",
    #      text: SOUTH_PASADENA[:name], visible: :all).trigger("click")
    assert_field("observation_place_name", with: SOUTH_PASADENA[:name])
    sleep(1)
    # debugger
    # Check the hidden fields returned by Google
    assert_hidden_location_fields_filled(SOUTH_PASADENA)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)

    assert_selector("[data-type='name'][data-autocompleter='connected']")
    fill_in("naming_name", with: "Agaricus campestris")
    assert_field("naming_name", with: "Agaricus campestris")
    select(Vote.confidence(Vote.next_best_vote), from: "naming_vote_value")
    assert_select("naming_vote_value",
                  selected: Vote.confidence(Vote.next_best_vote))

    within("#observation_form") { click_commit }

    assert_flash_for_create_location
    assert_selector("body.observations__show")

    assert_new_location_is_correct(expected_values_after_location)
    assert_new_observation_is_correct(expected_values_after_location)
    assert_show_observation_page_has_important_info

    # Open edit observation form
    # class selector is more robust in case the link becomes an icon:
    new_obs = Observation.last
    first(class: "edit_observation_link_#{new_obs.id}").trigger("click")
    # click_link("Edit Observation")
    assert_selector("body.observations__edit")

    # check the fields
    assert_field("observation_when_1i", with: "2010")
    assert_select("observation_when_2i", text: "August")
    assert_select("observation_when_3i", text: "14")
    assert_field("observation_place_name", with: SOUTH_PASADENA[:name])
    assert_image_gps_copied_to_obs(SO_PASA_EXIF)
    assert_unchecked_field("observation_is_collection_location")
    assert_checked_field("observation_specimen", visible: :all)
    assert_field(other_notes_id, with: "Notes for observation", visible: :all)

    imgs = Image.last(2)
    cci = imgs.find { |img| img[:original_name] == "Coprinus_comatus.jpg" }
    geo = imgs.find { |img| img[:original_name] == "geotagged_s_pasadena.jpg" }
    img_ids = imgs.map(&:id)
    imgs.each do |img|
      assert_field("good_image_#{img.id}_when_1i",
                   visible: :all, with: img.when.year.to_s)
      assert_select("good_image_#{img.id}_when_2i",
                    visible: :all, text: Date::MONTHNAMES[img.when.month])
      assert_select("good_image_#{img.id}_when_3i",
                    visible: :all, text: img.when.day.to_s)
      assert_field("good_image_#{img.id}_copyright_holder",
                   visible: :all, with: katrina.legal_name)
      assert_field("good_image_#{img.id}_notes",
                   visible: :all, with: "Notes for image")
    end
    assert_checked_field("thumb_image_id_#{cci.id}", visible: :all)
    assert_unchecked_field("thumb_image_id_#{geo.id}", visible: :all)

    # Test Bug Fix: Verify saved geotagged image extracts and displays EXIF GPS
    # Tests that JavaScript extracts EXIF from saved images, not just uploads
    find("#carousel_thumbnail_#{geo.id}").click
    geo_item = find("#carousel_item_#{geo.id}", visible: :all)
    within(geo_item) do
      # Camera Info should display GPS coordinates from the saved image
      assert_selector(".exif_lat", text: SO_PASA_EXIF[:lat].to_s, wait: 3)
      assert_selector(".exif_lng", text: SO_PASA_EXIF[:lng].to_s)
      assert_selector(".exif_alt", text: SO_PASA_EXIF[:alt].to_s)
    end

    # Submit observation form with changes
    obs_when = find("#observation_when_1i")
    scroll_to(obs_when, align: :center)
    fill_in("observation_when_1i", with: "2011")
    select("April", from: "observation_when_2i")
    select("15", from: "observation_when_3i")
    check("observation_is_collection_location")

    img_ids.each do |img_id|
      find("#carousel_thumbnail_#{img_id}").click
      fill_in("good_image_#{img_id}_when_1i", with: "2011")
      select("April", from: "good_image_#{img_id}_when_2i")
      select("15", from: "good_image_#{img_id}_when_3i")
      fill_in("good_image_#{img_id}_notes", with: "New notes for image")
    end

    obs_images = find("#observation_images")
    scroll_to(obs_images, align: :top)
    choose("thumb_image_id_#{geo.id}", visible: :all)
    sleep(1)

    # Move to the next step, Identification
    naming = find("#observation_naming_specimen")
    scroll_to(naming, align: :top)
    sleep(1)

    obs_notes = find("#observation_notes")
    scroll_to(obs_notes, align: :top)
    fill_in(other_notes_id, with: "New notes for observation")

    within("#observation_form") { click_commit }

    assert_selector("body.observations__show")
    assert_flash_for_edit_observation
    assert_edit_observation_is_correct(expected_values_after_edit)
    assert_show_observation_page_has_important_info

    # Make sure observation is in log index
    obs = Observation.last
    visit(activity_logs_path)
    assert_link(href: %r{/#{obs.id}?})

    # Destroy observation
    visit(observation_path(obs.id))
    new_obs = Observation.last
    assert_selector("body.observations__show")
    accept_confirm do
      find(".destroy_observation_link_#{new_obs.id}").click
    end
    assert_flash_for_destroy_observation
    assert_selector("body.observations__index")

    # Make sure observation is not in log index
    visit(activity_logs_path)
    assert_no_link(href: %r{/#{obs.id}/})
    assert_link(href: /activity_logs/, text: /Agaricus campestris/)
  end

  ##############################################################################
  #  Helper methods
  #

  # This image only has a date.
  COPRINUS_COMATUS_EXIF = {
    year: 2006,
    month: 11,
    day: 20
  }.freeze

  # The geotagged.jpg is from University Park, Florida.
  UNIVERSITY_PARK = {
    name: "University Park, Miami-Dade Co., Florida, USA",
    north: 25.762050,
    south: 25.733291,
    east: -80.351868,
    west: -80.385170
  }.freeze

  # The image geotagged.jpg has this data.
  GEOTAGGED_EXIF = {
    lat: 25.7582,
    lng: -80.3731,
    alt: 4,
    year: 2018,
    month: 12,
    day: 31
  }.freeze

  # Google seems to give accurate bounds to this place, but the
  # geometry.location_type of "Pasadena, California" is "APPROXIMATE".
  # Viewport and bounds are separate fields in the Geocoder response,
  # and other places' bounds may be more precise. Viewport may be padded.
  # On the right may be the accurate extents, they're hard to find.
  PASADENA_EXTENTS = {
    north: 34.251905,     # 34.1774839
    south: 34.1170368,    # 34.1275634561
    east: -118.0654789,   # -118.0989059
    west: -118.1981391,   # -118.1828198
    high: 1096.943603515625,
    low: 141.5890350341797,
    lat: 34.1477849,
    lng: -118.1445155,
    alt: 262.5840148925781
  }.freeze

  # Current results from Google Maps API, formatted by our JS map_controller.
  SOUTH_PASADENA = {
    name: "South Pasadena, Los Angeles Co., California, USA",
    north: 34.1257,
    south: 34.0986,
    east: -118.1347,
    west: -118.178,
    high: 235,
    low: 159
  }.freeze

  # The image geotagged_s_pasadena.jpg has this data.
  SO_PASA_EXIF = {
    lat: 34.1231,
    lng: -118.1489,
    alt: 248,
    year: 2020,
    month: 6,
    day: 30
  }.freeze

  def assert_date_is_now
    local_now = Time.zone.now.in_time_zone

    # check new observation form defaults
    assert_field("observation_when_1i", with: local_now.year.to_s)
    assert_select("observation_when_2i", text: local_now.strftime("%B"))
    assert_select("observation_when_3i", text: local_now.day.to_s)
  end

  def assert_geolocation_is_empty
    assert_field("observation_lat", with: "", visible: :all)
    assert_field("observation_lng", with: "", visible: :all)
    assert_field("observation_alt", with: "", visible: :all)
  end

  def assert_image_exif_available(image_data)
    assert_selector('[id$="when_1i"]', visible: :all)
    assert_selector('[id$="when_2i"]', visible: :all)
    assert_selector('[id$="when_3i"]', visible: :all)
    assert_equal(image_data[:year].to_s,
                 find('[id$="when_1i"]', visible: :all).value)
    assert_equal(image_data[:month].to_s,
                 find('[id$="when_2i"]', visible: :all).value)
    assert_equal(image_data[:day].to_s,
                 find('[id$="when_3i"]', visible: :all).value)
  end

  def assert_image_gps_copied_to_obs(image_data, status: "upload")
    # Wait for carousel item to be added
    carousel_item = find(
      ".carousel-item[data-image-status='#{status}']", wait: 10
    )

    # Navigate to the carousel item by clicking its thumbnail
    # (needed to view Camera Info for items with status 'good')
    img_uuid = carousel_item["data-image-uuid"]
    if img_uuid
      thumbnail = find(".carousel-indicator[data-image-uuid='#{img_uuid}']")
      thumbnail.click
      sleep(1) # Wait for carousel to transition
    end

    # For "good" images, wait for image load from server before EXIF extraction
    if status == "good"
      within(carousel_item) do
        # Wait for the carousel image element to be present and loaded
        assert_selector(".carousel-image[src]", wait: 10)
        sleep(2) # Give ExifReader time to fetch and process the image
      end
    end

    # Wait for EXIF data to be extracted (check for lat value in exif_gps span)
    assert_selector(".exif_lat", text: image_data[:lat].to_s, wait: 15)

    # Wait for "use exif" button to appear (not d-none)
    assert_selector(".use_exif_btn:not(.d-none)", wait: 10)

    # For the first image, JavaScript auto-transfers EXIF data and disables
    # the button. If the button is disabled, skip clicking it.
    unless has_button?(:image_use_exif.l, disabled: true)
      click_button(:image_use_exif.l)
    end

    # Wait for geolocation collapse to expand
    assert_selector("#observation_geolocation.in", wait: 10)

    # Verify GPS fields are populated
    assert_field("observation_lat", with: image_data[:lat].to_s, wait: 10)
    assert_field("observation_lng", with: image_data[:lng].to_s, wait: 10)
    # We look up the alt from lat/lng, so it's not copied from the image.
    # assert_field("observation_alt", with: image_data[:alt].to_i.to_s)
  end

  def assert_image_date_copied_to_obs(image_data)
    assert_equal(image_data[:year].to_s,
                 find('[id$="observation_when_1i"]').value)
    assert_equal(image_data[:month].to_s,
                 find('[id$="observation_when_2i"]').value)
    assert_equal(image_data[:day].to_s,
                 find('[id$="observation_when_3i"]').value)
  end

  def assert_hidden_location_fields_filled(location_data)
    assert_field("observation[location_id]", type: :hidden, with: "-1")
    assert_field("location_north", type: :hidden,
                                   with: location_data[:north].to_s)
    assert_field("location_south", type: :hidden,
                                   with: location_data[:south].to_s)
    assert_field("location_west", type: :hidden,
                                  with: location_data[:west].to_s)
    assert_field("location_east", type: :hidden,
                                  with: location_data[:east].to_s)
    # Will be waiting on a call to the elevation service. Maybe ready later.
    # assert_field("location_low", type: :hidden,
    #                              with: location_data[:low].to_s)
    # assert_field("location_high", type: :hidden,
    #                               with: location_data[:high].to_s)
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
    assert_gps_equal(expected_values[:lat], new_obs.lat.to_f)
    assert_gps_equal(expected_values[:lng], new_obs.lng.to_f)
    # We look up the alt from lat/lng, so it's not copied from the image.
    # assert_gps_equal(expected_values[:alt], new_obs.alt.to_f)
  end

  def assert_observation_has_correct_name(expected_values)
    new_obs = Observation.last
    consensus = Observation::NamingConsensus.new(new_obs)
    assert_names_equal(expected_values[:name], new_obs.name)
    assert_equal(expected_values[:vote],
                 consensus.user_votes(new_obs.user).first.value)
  end

  def assert_observation_has_correct_image(expected_values)
    new_obs = Observation.last
    new_imgs = Image.last(2)
    assert_obj_arrays_equal(new_imgs, new_obs.images)
    # Dates are no longer copied from image to obs/other images
    # assert_dates_equal(expected_values[:when], new_imgs[0].when)
    assert_equal(expected_values[:user].legal_name,
                 new_imgs[0].copyright_holder)
    assert_equal(expected_values[:image_notes], new_imgs[0].notes.strip)
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
    # new_img = Image.last
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
    # assert_text(new_img.notes) # nope, in the caption on carousel
    # assert_no_link(href: "observations?where")
    assert_link(href: /#{location_path(new_loc.id)}/)
    # assert_link(
    #   href: /#{Rails.application.routes.url_helpers.image_path(new_img.id)}/
    # )
  end

  def review_flash(patterns)
    patterns.each { |pat| assert_flash_success(pat) }
  end

  def assert_flash_for_images_uploaded
    review_flash([/uploaded image/i])
  end

  def assert_flash_for_create_observation
    review_flash([/success/i, /created observation/i,
                  /created proposed name/i])
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

  def other_notes_id
    Observation.notes_part_id(Observation.other_notes_part)
  end

  def expected_values_after_create
    {
      user: katrina,
      when: Date.parse("2010-08-14"),
      where: SOUTH_PASADENA[:name],
      location: nil,
      lat: SO_PASA_EXIF[:lat],
      lng: SO_PASA_EXIF[:lng],
      alt: SO_PASA_EXIF[:alt],
      name: names(:agaricus_campestris),
      vote: Vote.next_best_vote,
      is_collection_location: false,
      specimen: true,
      notes: "Notes for observation", # string displayed in observations/show
      image_notes: "Notes for image",
      thumb_image_id: Image.find_by(original_name: "Coprinus_comatus.jpg").id
    }
  end

  def expected_values_after_location
    expected_values_after_create.merge(
      where: nil,
      location: SOUTH_PASADENA[:name],
      north: SOUTH_PASADENA[:north],
      south: SOUTH_PASADENA[:south],
      east: SOUTH_PASADENA[:east],
      west: SOUTH_PASADENA[:west],
      high: SOUTH_PASADENA[:high],
      low: SOUTH_PASADENA[:low],
      location_notes: "Notes for location"
    )
  end

  def expected_values_after_edit
    expected_values_after_location.merge(
      when: Date.parse("2011-04-15"),
      # lat: 23.4567,
      # lng: -123.4567,
      # alt: 987,
      is_collection_location: true,
      specimen: false,
      notes: "New notes for observation", # displayed in observations/show
      image_notes: "New notes for image",
      thumb_image_id: Image.find_by(
        original_name: "geotagged_s_pasadena.jpg"
      ).id
    )
  end
end
