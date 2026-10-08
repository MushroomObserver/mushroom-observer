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
    # No JS/CSS driver here, so both the bar and dropdown copies of
    # the filter are present in the markup -- scope to one.
    within("#log_filter_form_bar_top") do
      click_link("Glossary")
    end

    assert_match("Activity Log", page.title)

    within("#log_filter_form_bar_top") do
      assert(has_checked_field?("type_glossary_term_top"))
      assert(has_unchecked_field?("type_observation_top"))
      assert(has_button?(:rss_make_default.l))
      click_button(:rss_make_default.l)
    end

    # No JS driver, so formaction/formmethod submits via a plain
    # POST through routes/CSRF, not a direct controller-action call.
    # back: "rss_logs" redirects here after saving the preference.
    assert_match("Activity Log", page.title)
    new_default = user.reload.default_rss_type
    assert_equal("glossary_term", new_default)
    assert_not_equal(original_default, new_default)
    # The redirect carries q[types] through, so the page lands back
    # on the same filter the user just saved, not an unfiltered index.
    within("#log_filter_form_bar_top") do
      assert(has_checked_field?("type_glossary_term_top"))
      assert(has_unchecked_field?("type_observation_top"))
    end
  end
end
