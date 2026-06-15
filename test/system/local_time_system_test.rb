# frozen_string_literal: true

require("application_system_test_case")

class LocalTimeSystemTest < ApplicationSystemTestCase
  def test_matrix_box_footer_time_converted_to_local
    login!(users("rolf"))

    # Visit observations index which has matrix boxes with timestamps
    visit("/")
    assert_selector("body.observations__index")

    # Find a matrix box with a time footer
    time_element = find(".rss-updated-at", match: :first, wait: 5)

    # Verify the Stimulus controller data attribute is present
    utc_value = time_element["data-local-time-utc-value"]
    assert(utc_value.present?, "Expected UTC value data attribute")
    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/,
                 utc_value,
                 "Expected ISO8601 UTC format")

    # Verify the displayed time format is YYYY-MM-DD HH:MM:SS TZ
    displayed_time = time_element.text
    assert_match(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \S+$/,
                 displayed_time,
                 "Expected local time format YYYY-MM-DD HH:MM:SS TZ")

    # Verify the controller connected by checking the time was converted
    # (The UTC and displayed times should differ unless in UTC timezone)
    # We can at least verify the JS ran by checking the format changed
    # from whatever the server rendered to our expected format
  end

  def test_local_time_controller_converts_utc_correctly
    login!(users("rolf"))

    visit("/")
    assert_selector("body.observations__index")
    assert_selector(".rss-updated-at", wait: 5)

    # Use JavaScript to verify the conversion is correct
    # We'll create a test element and verify the controller works
    result = evaluate_script(<<~JS)
      (function() {
        const el = document.querySelector('.rss-updated-at');
        if (!el) return { error: 'No element found' };

        const utcValue = el.dataset.localTimeUtcValue;
        if (!utcValue) return { error: 'No UTC value' };

        // Parse the UTC time and format in local time
        const date = new Date(utcValue);
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const seconds = String(date.getSeconds()).padStart(2, '0');
        const timezone = new Intl.DateTimeFormat('en-US', {
          timeZoneName: 'short'
        }).formatToParts(date).find(part => part.type === 'timeZoneName')?.value || '';
        const expectedLocal = `${year}-${month}-${day} ${hours}:${minutes}:${seconds} ${timezone}`;

        return {
          utcValue: utcValue,
          displayedTime: el.textContent.trim(),
          expectedLocal: expectedLocal,
          match: el.textContent.trim() === expectedLocal
        };
      })()
    JS

    assert_nil(result["error"], result["error"])
    assert(result["match"],
           "Displayed time '#{result["displayedTime"]}' should match " \
           "expected local time '#{result["expectedLocal"]}' " \
           "(from UTC: #{result["utcValue"]})")
  end
end
