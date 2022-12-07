# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < CapybaraIntegrationTestCase
  def setup
    super
    # Capybara.current_driver = :firefox_headless
  end

  def test_create_minimal_observation
    rolf = users("rolf")
    login!(rolf)

    click_on("Create Observation")
    assert_selector("body.observations__new")

    within("#observation_form") do
      assert_select("observation_when_1i", text: Date.today.year.to_s)
      assert_select("observation_when_2i", text: Date.today.strftime("%B"))
      assert_select("observation_when_3i", text: Date.today.strftime("%d").to_i)
      # assert_field("collection_number_name", with: users(:rolf).legal_name)
      # assert_field("herbarium_record_herbarium_name",
      #              with: users(:rolf).preferred_herbarium_name)
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
      fill_in("naming_name", with: "Elfin saddle")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end

    assert_flash_warning
    assert_flash_text(
      :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#name_messages", text: "MO does not recognize the name")

    within("#observation_form") do
      fill_in("naming_name", with: "Coprinus comatus")
      fill_in("observation_place_name", with: locations.first.name)
      click_commit
    end
  end
end
