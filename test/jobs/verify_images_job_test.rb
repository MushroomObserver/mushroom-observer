# frozen_string_literal: true

require("test_helper")

class VerifyImagesJobTest < ActiveJob::TestCase
  def test_calls_processor_verify_images_and_logs_summary
    result = { uploaded: ["320/1.jpg"], deleted: ["960/1.jpg", "640/2.jpg"],
               completed: [1], failed: ["640/3.jpg"], alerted: [] }

    Image::Processor.stub(:verify_images, result) do
      alerts = capture_alerts { VerifyImagesJob.perform_now }
      assert_empty(alerts, "no alert expected when nothing was flagged")
    end
  end

  def test_alerts_when_an_image_is_flagged
    result = { uploaded: [], deleted: [], completed: [], failed: [],
               alerted: [1] }

    Image::Processor.stub(:verify_images, result) do
      alerts = capture_alerts { VerifyImagesJob.perform_now }

      assert_equal(1, alerts.size)
      assert_instance_of(JobAlert, alerts.first)
      assert_includes(alerts.first.message, "1 image(s) marked transferred")
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
