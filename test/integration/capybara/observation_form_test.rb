# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < CapybaraIntegrationTestCase
  def test_create_minimal_observation
    mary = users("mary")
    login!(mary)

    click_on("Create Observation")
    assert_selector("body.observations__new")
  end
end
