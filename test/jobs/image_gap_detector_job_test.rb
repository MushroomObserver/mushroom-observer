# frozen_string_literal: true

require("test_helper")

class ImageGapDetectorJobTest < ActiveJob::TestCase
  def test_no_alert_when_no_gaps_found
    result = { gaps: [], regenerated: [], unregenerable: [] }

    Image::Processor.stub(:detect_gaps, result) do
      alerts = capture_alerts { ImageGapDetectorJob.perform_now }
      assert_empty(alerts)
    end
  end

  def test_alerts_with_summary_when_gaps_found
    result = {
      gaps: [[1, :remote1, "960/1.jpg"], [1, :remote2, "640/1.jpg"],
             [2, :remote1, "orig/2.jpg"]],
      regenerated: [1],
      unregenerable: [2]
    }

    Image::Processor.stub(:detect_gaps, result) do
      alerts = capture_alerts { ImageGapDetectorJob.perform_now }

      assert_equal(1, alerts.size)
      assert_instance_of(JobAlert, alerts.first)
      assert_includes(alerts.first.message, "3 gap(s) found across 2 image")
      assert_includes(alerts.first.message, "1 regenerated")
      assert_includes(alerts.first.message, "1 could not be regenerated")
      assert_includes(alerts.first.message, "[1, 2]")
    end
  end

  private

  # Records the exceptions handed to the #alerts pipeline while alerting is
  # forced active, so tests can assert on what a run would post to Slack.
  def capture_alerts(&block)
    alerts = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **_o|
                               alerts << exception
                             }, &block)
    end
    alerts
  end
end
