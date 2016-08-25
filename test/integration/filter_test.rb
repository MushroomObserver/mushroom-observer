require "test_helper"
require "capybara_helper"

# Test user filters
class FilterTest < IntegrationTestCase
  def test_user_filter_preferences
    user = users(:zero_user)
    assert_equal(false, user.filter_obs_imged)

    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    click_on("Preferences", match: :first)
    assert(page.has_content?("Observation Filters"),
           "Preference page lacks Observation Filters section")

    obs_imged_checkbox = find_field("user[filter_obs_imged]")
    refute(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be unchecked.")

    page.check("user[filter_obs_imged]")
    click_button("#{:SAVE_EDITS.t}", match: :first)
    user.reload
    assert_equal(true, user.filter_obs_imged)
  end
end
