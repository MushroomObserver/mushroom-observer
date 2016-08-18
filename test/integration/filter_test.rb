require "test_helper"
require "capybara_helper"

# Test typical sessions of user who never creates an account or contributes.
class FilterTest < IntegrationTestCase
  def test_user_preferences
    user = users(:mary)

    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    click_on("Preferences", match: :first)
    assert(page.has_content?("Observation Filters"),
           "Preference page lacks Observation Filters section")
  end
end
