# frozen_string_literal: true

require("application_system_test_case")

# The dropdown Apply button (RssLogs::TypeFilters) starts disabled
# and only enables once a checkbox's checked state differs from how
# the page loaded -- Stimulus (`type-filters` controller) + Bootstrap
# CSS behavior a controller/component test can't exercise.
class RssLogsTypeFiltersSystemTest < ApplicationSystemTestCase
  def test_apply_button_enables_only_while_checkbox_state_differs
    login!(users(:rolf))
    visit(activity_logs_path)
    assert_selector("body.rss_logs__index")

    find_by_id("log_filter_toggle_top").click
    assert_selector("#log_filter_menu_top.show")

    within("#log_filter_menu_top") do
      assert_apply_disabled

      check("type_observation_dropdown_top")
      assert_apply_enabled

      uncheck("type_observation_dropdown_top")
      assert_apply_disabled
    end
  end

  private

  def assert_apply_disabled
    assert_selector("button[data-type-filters-target='submit'][disabled]")
    assert_selector("div[data-type-filters-target='submitItem'].disabled")
  end

  def assert_apply_enabled
    assert_no_selector("button[data-type-filters-target='submit'][disabled]")
    assert_no_selector("div[data-type-filters-target='submitItem'].disabled")
  end
end
