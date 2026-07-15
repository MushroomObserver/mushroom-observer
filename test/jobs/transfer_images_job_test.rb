# frozen_string_literal: true

require("test_helper")

class TransferImagesJobTest < ActiveJob::TestCase
  def test_calls_processor_transfer_images_and_logs_summary
    result = { uploaded: ["320/1.jpg"], deleted: ["960/1.jpg"],
               completed: [1], failed: [] }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [1])
      end
      assert_empty(alerts, "no alert expected when nothing failed")
    end
  end

  def test_alerts_with_retry_command_when_a_file_fails
    result = { uploaded: [], deleted: [], completed: [],
               failed: [[1, :remote1, "640/1.jpg"]] }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [1])
      end

      assert_equal(1, alerts.size)
      assert_instance_of(JobAlert, alerts.first)
      assert_includes(alerts.first.message,
                      "TransferImagesJob.perform_now(image_ids: [1])")
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
