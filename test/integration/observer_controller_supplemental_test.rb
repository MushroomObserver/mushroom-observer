require "test_helper"

# Tests which supplement controller/observer_controller_test.rb
class ObserverControllerSupplementalTest < IntegrationTestCase
  def test_post_textile
    visit ("http://mushroomobserver.org/observer/textile_sandbox")
    fill_in("code", with: "Jabberwocky")
    click_button("Test")
    page.assert_text("Jabberwocky", count: 2)
  end
end
