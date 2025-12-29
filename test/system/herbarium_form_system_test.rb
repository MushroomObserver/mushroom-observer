# frozen_string_literal: true

require("application_system_test_case")

class HerbariumFormSystemTest < ApplicationSystemTestCase
  def test_create_fungarium_new_location
    rolf = users("rolf")
    login!(rolf)

    visit("/herbaria/new")
    assert_selector("body.herbaria__new")
    create_herbarium_with_new_location

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
    within("#herbarium_form") do
      assert_selector("#herbarium_place_name")
      fill_in("herbarium_place_name", with: "genohlac gard france")

      # Wait for create button to appear, then click via JS
      # (button text is hidden on small viewports via d-none d-sm-inline,
      # so Cuprite can't click it directly)
      assert_selector(".create-button", visible: :all, wait: 5)
      btn = find(".create-button", visible: :all)
      execute_script("arguments[0].click()", btn)

      # Verify autocompleter switched to location_google mode
      assert_selector("[data-type='location_google']", wait: 5)

      # Wait for hidden ID to be set (proves geocoding worked)
      assert_field("herbarium_location_id", with: "-1", type: :hidden, wait: 10)

      # Wait for geocoding to complete (async Google API call)
      assert_field("herbarium_place_name",
                   with: "Génolhac, Gard, Occitanie, France", wait: 10)

      # Verify hidden fields are populated correctly
      assert_field("location_north", with: "44.3726", type: :hidden)
      assert_field("location_east", with: "3.985", type: :hidden)
      assert_field("location_south", with: "44.3055", type: :hidden)
      assert_field("location_west", with: "3.9113", type: :hidden)

      fill_in("herbarium_name", with: "Herbarium des Cévennes")
      fill_in("herbarium_code", with: "CEV")
      click_commit
    end
  end
end
