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

    within("#herbarium_form") do
      fill_in("herbarium_name", with: "Herbarium des Cévennes")
      fill_in("herbarium_code", with: "CEV")
      click_commit
    end

    # assert_no_selector("#modal_herbarium")
    assert_selector("body.herbaria__show")
    assert_selector("h1", text: "Herbarium des Cévennes (CEV)")
    assert_selector("#herbarium_location",
                    text: "Génolhac, Gard, Occitanie, France")
  end
end
