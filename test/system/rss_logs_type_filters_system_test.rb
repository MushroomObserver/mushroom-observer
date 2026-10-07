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
      id = "type_observation_dropdown_top"
      initial = checkbox_checked?(id)

      toggle_checkbox(id)
      assert_equal(!initial, checkbox_checked?(id))
      assert_apply_enabled

      toggle_checkbox(id)
      assert_equal(initial, checkbox_checked?(id))
      assert_apply_disabled
    end
  end

  private

  # The custom-control input is visually hidden (opacity: 0) behind
  # its sibling label -- a click risks landing on the wrong target
  # (Cuprite coordinate-based clicks are unreliable on this markup
  # shape). Flip the DOM state directly instead.
  def toggle_checkbox(id)
    page.execute_script(<<~JS)
      const box = document.getElementById("#{id}")
      box.checked = !box.checked
      box.dispatchEvent(new Event("change", { bubbles: true }))
    JS
  end

  # `.checked` is a live property, not a reflected HTML attribute --
  # a CSS `[checked]` selector only sees the page-load value.
  def checkbox_checked?(id)
    page.evaluate_script("document.getElementById('#{id}').checked")
  end

  def assert_apply_disabled
    assert_selector("button[data-type-filters-target='submit'][disabled]")
    assert_selector("div[data-type-filters-target='submitItem'].disabled")
  end

  def assert_apply_enabled
    assert_no_selector("button[data-type-filters-target='submit'][disabled]")
    assert_no_selector("div[data-type-filters-target='submitItem'].disabled")
  end
end
