# frozen_string_literal: true

require("test_helper")

# Test that observation index displays times in the user's timezone
class ObservationsControllerTimezoneTest < FunctionalTestCase
  tests ObservationsController

  def setup
    super
    Location.update_box_area_and_center_columns
  end

  # Test that times in the index footer are displayed in the viewer's timezone
  # not the server's timezone
  def test_index_displays_time_in_viewer_timezone
    # Use UTC midnight to make timezone differences obvious
    utc_time = Time.utc(2024, 6, 15, 0, 0, 0) # Midnight UTC

    obs = Observation.create!(
      user: rolf,
      when: Date.new(2024, 6, 15),
      where: "Somewhere",
      name: names(:fungi)
    )

    # Create rss_log with specific updated_at time that will appear in footer
    rss_log = RssLog.create!(
      observation: obs,
      updated_at: utc_time,
      created_at: utc_time,
      notes: "test log entry"
    )

    obs.update!(rss_log: rss_log)

    # Set timezone to Pacific (UTC-7 in summer, UTC-8 in winter)
    # On June 15, Pacific Daylight Time is UTC-7
    # So midnight UTC = 5:00 PM PDT previous day (June 14)
    pacific_tz = "America/Los_Angeles"

    login
    cookies[:tz] = pacific_tz
    get(:index, params: { id: obs.id })

    # Expected time in Pacific timezone
    # UTC 2024-06-15 00:00:00 should display as
    # PDT 2024-06-14 17:00:00 (UTC-7)
    expected_date = "2024-06-14"
    expected_time = "17:00:00"

    # The footer should contain the time formatted in Pacific timezone
    # Looking for the pattern YYYY-MM-DD HH:MM:SS in the box for our observation
    box_id = "box_#{obs.id}"
    
    # First, verify the box exists in the response
    assert_select("##{box_id}", { count: 1 }, 
                  "Could not find observation box with id='#{box_id}' in the response")
    
    assert_select("##{box_id} .log-footer .rss-what", /#{expected_date}\s+#{expected_time}/,
                  "Index should display time '#{expected_date} #{expected_time}' in " \
                  "Pacific timezone (UTC-7), not '2024-06-15 00:00:00' in UTC/server time")

    # Also verify it does NOT show the UTC/server time in this box
    # (This is the failing assertion that proves timezone conversion works)
    assert_select("##{box_id} .log-footer .rss-what") do |elements|
      elements.each do |element|
        assert_no_match(/2024-06-15\s+00:00:00/, element.text,
                        "Index should NOT display the UTC/server time, it should convert to viewer's timezone")
      end
    end
  end
end
