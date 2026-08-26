# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/rss_logs_controller_test.rb
class ActivityLogIntegrationTest < CapybaraIntegrationTestCase
  # Prove that MO offers to make non-default log the user's default.
  def test_user_default_rss_log
    user = users(:zero_user)
    login(user)
    visit("/activity_logs")
    within("#log_filter_form") do
      click_link("Glossary")
    end

    assert_match("Activity Log", page.title)

    within("#log_filter_form") do
      assert(has_checked_field?("type_glossary_term"))
      assert(has_unchecked_field?("type_observation"))
      assert(has_button?(:rss_make_default.l))
      click_button(:rss_make_default.l)
    end

    # No JS driver here, so the button's formaction/formmethod submit
    # via a plain (non-Turbo) POST -- goes through the route table,
    # Rack::MethodOverride, and CSRF checks, unlike a controller test
    # calling the action directly. A successful PATCH redirects to
    # the edit page and saves the preference.
    assert_match("Preferences", page.title)
    assert_equal("glossary_term", user.reload.default_rss_type)
  end
end
