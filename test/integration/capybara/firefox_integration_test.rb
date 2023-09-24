# frozen_string_literal: true

require("test_helper")

class FirefoxIntegrationTest < CapybaraIntegrationTestCase
  # Uncomment this to try running tests with firefox_headless browser
  def setup
    super
    Capybara.current_driver = :selenium_headless # or :firefox_headless
  end

  def test_minimal_create_observation
    rolf = users("rolf")
    login!(rolf)

    click_on("Create Observation")
    assert_selector("body.observations__new")
  end
end
