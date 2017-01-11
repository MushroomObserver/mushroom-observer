require "test_helper"

# Tests which supplement controller/observer_controller_test.rb
class ObserverControllerSupplementalTest < IntegrationTestCase
  def test_post_textile
    visit("/observer/textile_sandbox")
    fill_in("code", with: "Jabberwocky")
    click_button("Test")
    page.assert_text("Jabberwocky", count: 2)
  end

  def test_map_observations
    name = names(:boletus_edulis)
    visit("/name/map/#{name.id}")
    click_link("Show Observations")
    click_link("Show Map")
    title = page.find_by_id("title")

    title.assert_text("Observations of #{name.text_name}")
  end
end
