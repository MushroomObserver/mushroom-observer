# frozen_string_literal: true

require("application_system_test_case")

class ObservationFormSystemTest < ApplicationSystemTestCase
  def test_create_minimal_observation
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
      send_keys(:down) # cursor down to the first match
      send_keys(:tab) # select currently highlighted row
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
      send_keys(:down) # cursor down to the first match
      send_keys(:tab) # select currently highlighted row
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
end
