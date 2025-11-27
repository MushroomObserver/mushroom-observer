# frozen_string_literal: true

require("test_helper")

# Tests of displayed time
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
      when: utc_time.to_date,
      where: "Somewhere",
      name: names(:fungi)
    )

    rss_log = RssLog.create!(
      observation: obs,
      updated_at: utc_time,
      created_at: utc_time,
      notes: "test log entry"
    )

    obs.update!(rss_log: rss_log)

    # Set viewer's timezone: Pacific (UTC-7 in summer, UTC-8 in winter)
    viewer_tz = "America/Los_Angeles"
    expected_date = utc_time.in_time_zone(viewer_tz).strftime("%Y-%m-%d")
    expected_time = utc_time.in_time_zone(viewer_tz).strftime("%H:%M:%S")
    utc_date = utc_time.strftime("%Y-%m-%d")
    utc_time_str = utc_time.strftime("%H:%M:%S")

    login
    cookies[:tz] = viewer_tz
    get(:index, params: { id: obs.id })

    # The footer should contain the time formatted in Pacific timezone
    box_id = "box_#{obs.id}"

    assert_select(
      "##{box_id}", { count: 1 },
      "Response is missing observation box with id='#{box_id}'"
    )

    assert_select("##{box_id} .log-footer .rss-what",
                  /#{expected_date}\s+#{expected_time}/,
                  "Index should display hour in viewer's timezone")
    assert_select("##{box_id} .log-footer .rss-what") do |elements|
      elements.each do |element|
        assert_no_match(/#{utc_date}\s+#{utc_time_str}/, element.text,
                        "Index should convert to viewer's timezone")
      end
    end
  end
end
