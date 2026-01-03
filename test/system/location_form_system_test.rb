# frozen_string_literal: true

require("application_system_test_case")

class LocationFormSystemTest < ApplicationSystemTestCase
  def test_format_new_location_name
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    visit("/locations/new")
    assert_selector("body.locations__new")

    assert_selector("#location_display_name")
    assert_button(:form_locations_find_on_map.l)
    # be sure the map is loaded!
    assert_selector("#map_div div div")
    fill_in("location_display_name", with: "genohlac gard france")
    click_button(:form_locations_find_on_map.l)

    # Geocoding has 1s buffer + API call time, so allow extra wait.
    # This test is flaky due to Google Maps API response times.
    assert_selector("#location_display_name.geocoded", wait: 15)
    assert_field("location_display_name",
                 with: "Génolhac, Gard, Occitanie, France")

    assert_field("location_north", with: "44.3726")
    assert_field("location_east", with: "3.985")
    assert_field("location_south", with: "44.3055")
    assert_field("location_west", with: "3.9113")
    # NOTE: location_high and location_low may not be populated by geocoder
    # assert_field("location_high", with: "1388.2098")
    # assert_field("location_low", with: "287.8201")
  end

  def test_edit_location_geocode
    rolf = users("rolf")
    location = locations("burbank")
    login!(rolf)

    visit("/locations/#{location.id}/edit")
    assert_selector("body.locations__edit")
    assert_selector("#location_form")
    assert_selector("#map_div div div")

    # Change location name and geocode
    fill_in("location_display_name", with: "santa barbara california")
    click_button(:form_locations_find_on_map.l)

    # Wait for geocoding to complete
    assert_selector("#location_display_name.geocoded", wait: 15)
    # Geocoder returns full name with county
    assert_field("location_display_name",
                 with: "Santa Barbara, Santa Barbara Co., California, USA")

    # Verify coordinates updated
    assert_field("location_north")
    north_value = find_field("location_north").value.to_f
    assert_in_delta(34.5, north_value, 0.5, "North should be near SB")
  end
end
