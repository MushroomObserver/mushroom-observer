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
    within("#observation_form") do
      # MOAutocompleter replaces year select with text field
      assert_field("observation_when_1i", with: Time.zone.today.year.to_s)
      assert_select("observation_when_2i", text: Time.zone.today.strftime("%B"))
      # %e is day of month, no leading zero
      assert_select("observation_when_3i", text: Time.zone.today.strftime("%e"))
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
      fill_in("naming_name", with: "Elfin saddle")
      # don't wait for the autocompleter - we know it's an elfin saddle!
      browser.keyboard.type(:tab)
      assert_field("naming_name", with: "Elfin saddle")
      # start typing the location...
      fill_in("observation_place_name", with: locations.first.name[0, 10])
      # wait for the autocompleter...
      assert_selector(".auto_complete")
      browser.keyboard.type(:down, :tab) # cursor to first match + select row
      assert_field("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_selector("#name_messages", text: "MO does not recognize the name")
    assert_flash_error(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#observation_form")

    # hard to test the internals of map, but this will pick up map load errors
    # click_button("locate_on_map")
    # assert_selector("#observation_form_map > div > div > iframe")

    within("#observation_form") do
      fill_in("naming_name", with: "Coprinus com")
      browser.keyboard.type(:tab)
      # wait for the autocompleter!
      assert_selector(".auto_complete")
      browser.keyboard.type(:down, :tab) # cursor to first match + select row
      browser.keyboard.type(:tab)
      assert_field("naming_name", with: "Coprinus comatus")
      # Place name should stay filled
      browser.keyboard.type(:tab)
      assert_field("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_selector("body.observations__show")
    assert_flash_success(/created observation/i)
  end

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

  def test_post_edit_and_destroy_with_details_and_location
    browser = page.driver.browser
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

    assert_field("observation_place_name", with: "")
    assert_field("observation_lat", with: "")
    assert_field("observation_lng", with: "")
    assert_field("observation_alt", with: "")

    assert_field("naming_name", with: "")
    assert_checked_field("observation_is_collection_location")
    assert_no_checked_field("observation_specimen")
    assert_field(other_notes_id, with: "")

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
      assert_equal("2006", find('[id$="when_1i"]', visible: :all).value)
      assert_equal("11", find('[id$="when_2i"]', visible: :all).value)
      assert_equal("20", find('[id$="when_3i"]', visible: :all).value)
    end

    # Add a second image that's geotagged.
    click_attach_file("geotagged.jpg")
    sleep(0.5)
    # Be sure we have two image wrappers. We have to wait for
    # the first one to be hidden before we can see the second one.
    image_wrappers = all(".carousel-item[data-image-status='upload']",
                         visible: :all)
    assert_equal(2, image_wrappers.length)
    # The new one is prepended, so second is "first"
    second_image_wrapper = image_wrappers[0]

    # Check that it's the right image: this is geotagged.jpg's date
    within(second_image_wrapper) do
      assert_equal("2018", find('[id$="when_1i"]', visible: :all).value)
      assert_equal("12", find('[id$="when_2i"]', visible: :all).value)
      assert_equal("31", find('[id$="when_3i"]', visible: :all).value)
    end

    # Date should have been copied to the obs fields
    assert_equal("2018", find('[id$="observation_when_1i"]').value)
    assert_equal("12", find('[id$="observation_when_2i"]').value)
    assert_equal("31", find('[id$="observation_when_3i"]').value)

    # GPS should have been copied to the obs fields
    assert_equal("25.7582", find('[id$="observation_lat"]').value)
    assert_equal("-80.3731", find('[id$="observation_lng"]').value)
    assert_equal("4", find('[id$="observation_alt"]').value.to_i.to_s)

    # Ok, enough. By now, the carousel image should be showing the second image.
    assert_selector(
      ".carousel-item[data-image-status='upload'][data-stimulus='connected']",
      visible: :visible, wait: 3
    )
    # Try removing the geotagged image
    scroll_to(second_image_wrapper, align: :center)
    within(second_image_wrapper) { find(".remove_image_button").click }

    # Be sure we have only one image wrapper now
    image_wrappers = all(".carousel-item[data-image-status='upload']",
                         visible: :all)
    assert_equal(1, image_wrappers.length)

    # Add geotagged.jpg again
    click_attach_file("geotagged.jpg")
    sleep(0.5)

    # Be sure we have two image wrappers
    second_image_wrapper = find(".carousel-item[data-image-status='upload']",
                                text: "25.7582")
    image_wrappers = all(".carousel-item[data-image-status='upload']",
                         visible: :all)
    assert_equal(image_wrappers.length, 2)

    within(second_image_wrapper) do
      assert_equal("2018", find('[id$="when_1i"]').value)
      assert_equal("12", find('[id$="when_2i"]').value)
      assert_equal("31", find('[id$="when_3i"]').value)
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

    # Fill out some other stuff
    obs_when = find("#observation_when_1i")
    scroll_to(obs_when, align: :center)
    fill_in("observation_when_1i", with: "2010")
    select("March", from: "observation_when_2i")
    select("14", from: "observation_when_3i")

    # intentional error: nonexistant place name
    location = find("#observation_place_name")
    scroll_to(location, align: :center)
    fill_in("observation_place_name", with: "USA, California, Pasadena")
    assert_field("observation_place_name", with: "USA, California, Pasadena")
    uncheck("observation_is_collection_location")
    check("observation_specimen")

    assert_selector("#collection_number_number")
    fill_in("collection_number_number", with: "17-034a")
    fill_in(other_notes_id, with: "Notes for observation")

    # Inherited project constraints maybe messing with this observation - clear
    all('[id^="project_id_"]').each do |project_checkbox|
      project_checkbox.click if project_checkbox.checked?
    end

    # submit_observation_form_with_errors
    within("#observation_form") { click_commit }

    # rejected, but images uploaded
    assert_selector("body.observations__create", wait: 12)
    assert_flash_for_images_uploaded
    assert_has_location_warning(/Unknown country/)

    # check form values after first changes
    assert_field("observation_when_1i", with: "2010")
    assert_select("observation_when_2i", text: "March")
    assert_select("observation_when_3i", text: "14")

    assert_field("observation_place_name", with: "USA, California, Pasadena")
    assert_field("observation_lat", with: "25.7582")
    assert_field("observation_lng", with: "-80.3731")
    assert_field("observation_alt", with: "4")

    assert_field("naming_name", with: "")
    assert_no_checked_field("observation_is_collection_location")
    assert_checked_field("observation_specimen")
    assert_field("collection_number_number", with: "17-034a")
    assert_field(other_notes_id, with: "Notes for observation")

    # submit_observation_form_without_errors
    fill_in("observation_place_name", with: "Pasadena, Calif")
    browser.keyboard.type(:tab)
    assert_selector(".auto_complete")
    browser.keyboard.type(:down, :tab) # cursor down to first match + select row
    assert_field("observation_place_name", with: "Pasadena, California, USA")
    # geo-coordinates-parser will reject internally-inconsistent notation.
    fill_in("observation_lat", with: " 12deg 36.75min N ") # == 12.6125
    fill_in("observation_lng", with: " 121deg 33.14min E ") # == 121.5523
    fill_in("observation_alt", with: " 56 ft. ")

    fill_in("naming_name", with: "Agaricus campe")
    assert_selector(".auto_complete")
    assert_selector(".auto_complete ul li", text: "Agaricus campestris")
    browser.keyboard.type(:down, :down, :tab) # down to second match + select
    assert_field("naming_name", with: "Agaricus campestris")
    select(Vote.confidence(Vote.next_best_vote), from: "naming_vote_value")
    assert_select("naming_vote_value",
                  selected: Vote.confidence(Vote.next_best_vote))

    # Carousel items are re-output with image records this time.
    all(".carousel-indicator").last.click

    second_item = find(".carousel-item", text: "25.7582")
    items = all(".carousel-item", visible: :all)
    assert_equal(items.length, 2)

    within(second_item) do
      assert_equal("2018", find('[id$="when_1i"]').value)
      assert_equal("12", find('[id$="when_2i"]').value)
      assert_equal("31", find('[id$="when_3i"]').value)
    end

    within("#observation_form") { click_commit }

    # It should take us to create a new location
    assert_selector("body.locations__new")
    # The observation shoulda been created OK.
    assert_flash_for_create_observation
    # Check the db values
    assert_new_observation_is_correct(expected_values_after_create)

    # check default values of location form
    assert_field("location_display_name", with: "Pasadena, California, USA")
    assert_button(text: :form_locations_find_on_map.t.as_displayed)
    click_button(:form_locations_find_on_map.t.as_displayed)
    sleep(1)
    assert_equal(PASADENA_EXTENTS[:north].round(4),
                 find("#location_north").value.to_f.round(4))
    assert_equal(PASADENA_EXTENTS[:south].round(4),
                 find("#location_south").value.to_f.round(4))
    assert_equal(PASADENA_EXTENTS[:east].round(4),
                 find("#location_east").value.to_f.round(4))
    assert_equal(PASADENA_EXTENTS[:west].round(4),
                 find("#location_west").value.to_f.round(4))
    sleep(1) # wait for elevation service
    assert_equal(PASADENA_EXTENTS[:high].round(4),
                 find("#location_high").value.to_f.round(4))
    assert_equal(PASADENA_EXTENTS[:low].round(4),
                 find("#location_low").value.to_f.round(4))

    # submit_location_form_with_errors
    fill_in("location_display_name",
            with: "Pasadena: Disneyland, Some Co., California, USA")
    fill_in("location_notes", with: "oops")

    within("#location_form") { click_commit }

    assert_selector("body.locations__create")
    assert_has_location_warning(/Contains unexpected character/)

    assert_field("location_display_name",
                 with: "Pasadena: Disneyland, Some Co., California, USA")
    assert_field("location_notes", with: "oops")

    # submit_location_form_without_errors
    fill_in("location_display_name",
            with: "Pasadena, Some Co., California, USA")
    fill_in("location_notes", with: "Notes for location")

    within("#location_form") { click_commit }

    assert_flash_for_create_location
    assert_selector("body.observations__show")

    # https://gorails.com/episodes/rails-system-testing-file-uploads
    #
    # attach_file "user[avatar]", file_fixture("avatar.jpg")
    # find(".dropzone").drop File.join(file_fixture_path, "avatar.jpg")

    assert_new_location_is_correct(expected_values_after_location)
    assert_new_observation_is_correct(expected_values_after_location)
    assert_show_observation_page_has_important_info

    # open_edit_observation_form
    # This is more robust in case the link becomes an icon:
    new_obs = Observation.last
    first(class: "edit_observation_link_#{new_obs.id}").trigger("click")
    # click_link("Edit Observation")
    assert_selector("body.observations__edit")

    # check the fields
    assert_field("observation_when_1i", with: "2010")
    assert_select("observation_when_2i", text: "March")
    assert_select("observation_when_3i", text: "14")
    assert_field("observation_place_name",
                 with: "Pasadena, Some Co., California, USA")
    assert_field("observation_lat", with: "12.6125") # was 12.5927
    assert_field("observation_lng", with: "121.5523") # was -121.5525
    assert_field("observation_alt", with: "17")
    assert_unchecked_field("observation_is_collection_location")
    assert_checked_field("observation_specimen")
    assert_field(other_notes_id, with: "Notes for observation")

    imgs = Image.last(2)
    cci = imgs.find { |img| img[:original_name] == "Coprinus_comatus.jpg" }
    geo = imgs.find { |img| img[:original_name] == "geotagged.jpg" }
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

    # submit_observation_form_with_changes
    obs_when = find("#observation_when_1i")
    scroll_to(obs_when, align: :center)
    fill_in("observation_when_1i", with: "2011")
    select("April", from: "observation_when_2i")
    select("15", from: "observation_when_3i")
    fill_in("observation_lat", with: "23.4567")
    fill_in("observation_lng", with: "-123.4567")
    fill_in("observation_alt", with: "987m")
    check("observation_is_collection_location")
    fill_in(other_notes_id, with: "New notes for observation")
    img_ids.each do |img_id|
      find("#carousel_thumbnail_#{img_id}").click
      fill_in("good_image_#{img_id}_when_1i", with: "2011")
      select("April", from: "good_image_#{img_id}_when_2i")
      select("15", from: "good_image_#{img_id}_when_3i")
      fill_in("good_image_#{img_id}_notes", with: "New notes for image")
    end
    obs_images = find("#observation_images")
    scroll_to(obs_images, align: :top)
    choose("thumb_image_id_#{geo.id}")
    sleep(1)

    within("#observation_form") { click_commit }

    assert_selector("body.observations__show")
    assert_flash_for_edit_observation
    assert_edit_observation_is_correct(expected_values_after_edit)
    assert_show_observation_page_has_important_info

    # make_sure_observation_is_in_log_index
    obs = Observation.last
    visit(activity_logs_path)
    assert_link(href: %r{/#{obs.id}?})

    # destroy_observation
    visit(observation_path(obs.id))
    new_obs = Observation.last
    assert_selector("body.observations__show")
    accept_confirm do
      find(".destroy_observation_link_#{new_obs.id}").click
    end
    assert_flash_for_destroy_observation
    assert_selector("body.observations__index")

    # make_sure_observation_is_not_in_log_index
    visit(activity_logs_path)
    assert_no_link(href: %r{/#{obs.id}/})
    assert_link(href: /activity_logs/, text: /Agaricus campestris/)
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
    assert_gps_equal(expected_values[:alt], new_obs.alt.to_f)
  end

  def assert_observation_has_correct_name(expected_values)
    new_obs = Observation.last
    consensus = Observation::NamingConsensus.new(new_obs)
    assert_names_equal(expected_values[:name], new_obs.name)
    assert_equal(expected_values[:vote], consensus.owners_votes.first.value)
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
      when: Date.parse("2010-03-14"),
      where: "Pasadena, California, USA",
      location: nil,
      lat: 12.6125, # was 12.5760 values tweaked to move it to land
      lng: 121.5523, # was -123.7519 was in the ocean
      alt: 17,
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
      lng: -123.4567,
      alt: 987,
      is_collection_location: true,
      specimen: false,
      notes: "New notes for observation", # displayed in observations/show
      image_notes: "New notes for image",
      thumb_image_id: Image.find_by(original_name: "geotagged.jpg").id
    )
  end
end
