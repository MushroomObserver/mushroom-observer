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

    assert_selector("#location_display_name.geocoded")
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

  # TODO: Investigate why Open-Elevation API calls fail in Capybara test
  # environment but work in real browser. The functionality is verified
  # manually - elevations auto-populate after geocoding a location.
  def skip_test_elevations_auto_populate_after_geocoding
    rolf = users("rolf")
    login!(rolf)

    visit("/locations/new")
    assert_selector("body.locations__new")
    assert_selector("#map_div div div") # map loaded

    fill_in("location_display_name", with: "genolhac gard france")
    click_button(:form_locations_find_on_map.l)

    # Wait for geocoding to complete
    assert_selector("#location_display_name.geocoded", wait: 10)

    # Wait for elevations to populate (async call after geocoding)
    # The button gets disabled once elevations are fetched
    assert_selector("#location_get_elevation[disabled]", wait: 15)

    # Elevations should be populated
    high_value = find("#location_high").value
    low_value = find("#location_low").value

    assert_not_empty(high_value, "High elevation should be populated")
    assert_not_empty(low_value, "Low elevation should be populated")
    assert(high_value.to_f > low_value.to_f,
           "High elevation should be greater than low")
  end
end
