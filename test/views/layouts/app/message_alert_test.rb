# frozen_string_literal: true

require("test_helper")

module Views::Layouts::App
  class MessageAlertTest < ComponentTestCase
    # observation_resync_failed's translation stores its apostrophe as
    # the HTML entity &#8217; -- as_displayed decodes it back to a real
    # apostrophe for comparison against Nokogiri's own decoded .text.
    # This fails if the entity gets double-escaped (an earlier bug).
    def test_renders_trusted_message_not_double_escaped
      html = render(MessageAlert.new(
                      message: :observation_resync_failed.t, level: :danger
                    ))

      assert_html(html, "div.alert.alert-danger#flash_notices",
                  text: :observation_resync_failed.t.as_displayed)
    end

    def test_level_drives_alert_class
      html = render(MessageAlert.new(message: "Done", level: :success))

      assert_html(html, "div.alert.alert-success", text: "Done")
    end
  end
end
