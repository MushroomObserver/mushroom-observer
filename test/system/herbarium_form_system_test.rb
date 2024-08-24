# frozen_string_literal: true

require("application_system_test_case")

class HerbariumFormSystemTest < ApplicationSystemTestCase
  def test_fungarium_new_location
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    assert_selector("body.herbaria__new")

    assert_selector("#herbarium_place_name")
    fill_in("herbarium_place_name", with: "genohlac gard france")
    assert_link(:form_observations_create_locality.l)
    # be sure the map is loaded!
    # assert_selector("#map_div div div")
    click_link(:form_observations_create_locality.l)

    assert_selector("#herbarium_place_name.geocoded")
    assert_field("herbarium_place_name",
                 with: "Génolhac, Gard, Occitanie, France")

    assert_field("herbarium_location_id", with: "-1", type: :hidden)
    assert_field("location_north", with: "44.3726", type: :hidden)
    assert_field("location_east", with: "3.985", type: :hidden)
    assert_field("location_south", with: "44.3055", type: :hidden)
    assert_field("location_west", with: "3.9113", type: :hidden)
    assert_field("location_high", with: "1388.2098", type: :hidden)
    assert_field("location_low", with: "287.8201", type: :hidden)
  end
end
