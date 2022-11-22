# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < CapybaraIntegrationTestCase
  def test_create_minimal_observation
    rolf = users("rolf")
    login!(rolf)

    click_on("Create Observation")
    assert_selector("body.observations__new")
    # binding.break

    within("#observation_form") do
      assert_field("collection_number_name", with: users(:rolf).legal_name)
      assert_field("herbarium_record_herbarium_name",
                   with: users(:rolf).preferred_herbarium_name)
      assert_selector("#where_help",
                      text: "Albion, Mendocino Co., California")
    end
  end
end
