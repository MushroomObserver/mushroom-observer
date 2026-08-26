# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/rss_logs_controller_test.rb
class ActivityLogIntegrationTest < CapybaraIntegrationTestCase
  # Prove that MO offers to make non-default log the user's default.
  def test_user_default_rss_log
    user = users(:zero_user)
    original_default = user.default_rss_type
    login(user)
    assert_not_equal("glossary_term", original_default,
                     "Fixture default_rss_type already matches the " \
                     "type this test selects -- pick a fixture where " \
                     "it doesn't, so the assertion below proves a change")
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
    # calling the action directly. A successful PATCH saves the
    # preference and, via back: "rss_logs", redirects here instead
    # of the account prefs edit page.
    assert_match("Activity Log", page.title)
    new_default = user.reload.default_rss_type
    assert_equal("glossary_term", new_default)
    assert_not_equal(original_default, new_default)
    # The redirect carries q[types] through, so the page lands back
    # on the same filter the user just saved, not an unfiltered index.
    within("#log_filter_form") do
      assert(has_checked_field?("type_glossary_term"))
      assert(has_unchecked_field?("type_observation"))
    end
  end
end
