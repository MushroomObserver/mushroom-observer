# frozen_string_literal: true

require("application_system_test_case")

class ObservationsSystemTest < ApplicationSystemTestCase
  def test_create_minimal_observation
    rolf = users("rolf")
    login!(rolf)

    assert(page.has_link?("Create Observation"))
    click_on("Create Observation")

    assert(page.has_selector?("body.observations__new"))
    within("#observation_form") do
      # MOAutocompleter has replaced year select with text field
      assert_field("observation_when_1i", with: Time.zone.today.year.to_s)
      assert_select("observation_when_2i", text: Time.zone.today.strftime("%B"))
      assert_select("observation_when_3i",
                    text: Time.zone.today.strftime("%d").to_i)
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
      fill_in("naming_name", with: "Elfin saddle")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert(page.has_selector?("#name_messages",
                              text: "MO does not recognize the name"))
    assert_flash_warning
    assert_flash_text(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )

    assert(page.has_selector?("#observation_form"))
    within("#observation_form") do
      fill_in("naming_name", with: "Coprinus comatus")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert(page.has_selector?("body.observations__show"))
    assert_flash_success
    assert_flash_text(:runtime_observation_success.t.html_to_ascii)
  end
end
