# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/rss_logs_controller_test.rb
class ActivityLogIntegrationTest < CapybaraIntegrationTestCase
  # Prove that MO offers to make non-default log the user's default.
  def test_user_default_rss_log
    login
    visit("/activity_logs")
    within("#log_filter_form") do
      click_link("Glossary")
    end

    title = page.find_by_id("title")
    title.assert_text("Activity Log")

    within("#log_filter_form") do
      assert(has_checked_field?("type_glossary_term"))
      assert(has_unchecked_field?("type_observation"))
    end

    within("#header") do
      assert(has_link?(:rss_make_default.l))
    end
  end
end
