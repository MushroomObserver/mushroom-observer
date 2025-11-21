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
end
