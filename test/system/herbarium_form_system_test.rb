# frozen_string_literal: true

require("application_system_test_case")

class HerbariumFormSystemTest < ApplicationSystemTestCase
  def test_create_fungarium_new_location
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    assert_selector("body.herbaria__new")
    create_herbarium_with_new_location

    # assert_no_selector("#modal_herbarium")
    assert_selector("body.herbaria__show")
    assert_selector("h1", text: "Herbarium des Cévennes (CEV)")
    assert_selector("#herbarium_location",
                    text: "Génolhac, Gard, Occitanie, France")
  end

  def test_observation_form_create_fungarium_new_location
    rolf = users("rolf")
    login!(rolf)

    visit("/observations/new")
    assert_selector("body.observations__new")

    assert_selector("#observation_naming_specimen")
    scroll_to(find("#observation_naming_specimen"), align: :top)
    check("observation_specimen")
    assert_selector("#herbarium_record_herbarium_name")
    assert_selector(".create-link", text: :create_herbarium.l)
    click_link(:create_herbarium.l)

    assert_selector("#modal_herbarium")
    create_herbarium_with_new_location

    assert_no_selector("#modal_herbarium")
    assert_field("herbarium_record_herbarium_name",
                 with: "Herbarium des Cévennes")
  end

  def create_herbarium_with_new_location
    assert_selector("#herbarium_place_name")
    fill_in("herbarium_place_name", with: "genohlac gard france")
    assert_link(:form_observations_create_locality.l)
    click_link(:form_observations_create_locality.l)

    assert_field("herbarium_place_name",
                 with: "Génolhac, Gard, Occitanie, France")

    assert_field("herbarium_location_id", with: "-1", type: :hidden)
    assert_field("location_north", with: "44.3726", type: :hidden)
    assert_field("location_east", with: "3.985", type: :hidden)
    assert_field("location_south", with: "44.3055", type: :hidden)
    assert_field("location_west", with: "3.9113", type: :hidden)
    # NOTE: location_high and location_low may not be populated by geocoder
    # assert_field("location_high", with: "1388.2098", type: :hidden)
    # assert_field("location_low", with: "287.8201", type: :hidden)

    within("#herbarium_form") do
      fill_in("herbarium_name", with: "Herbarium des Cévennes")
      fill_in("herbarium_code", with: "CEV")
      click_commit
    end
  end
end
