# frozen_string_literal: true

require("test_helper")

class TransferImagesJobTest < ActiveJob::TestCase
  def test_calls_processor_transfer_images_and_logs_summary
    result = { uploaded: ["320/1.jpg"], deleted: ["960/1.jpg"],
               completed: [1], failed: [], stuck: [] }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [1])
      end
      assert_empty(alerts, "no alert expected when nothing failed")
      assert_no_enqueued_jobs(only: TransferImagesJob)
    end
  end

  # A transient upload failure retries itself with backoff (#4974)
  # instead of immediately alerting a human whose remedy would be to run
  # the same job again.
  def test_failed_upload_requeues_itself_instead_of_alerting
    result = { uploaded: [], deleted: [], completed: [],
               failed: [[1, :remote1, "640/1.jpg"]], stuck: [] }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [1])
      end

      assert_empty(alerts, "first failure should retry, not alert")
      assert_enqueued_with(job: TransferImagesJob,
                           args: [{ image_ids: [1] }])
    end
  end

  def test_alerts_with_retry_command_once_attempts_are_exhausted
    result = { uploaded: [], deleted: [], completed: [],
               failed: [[1, :remote1, "640/1.jpg"]], stuck: [] }
    job = TransferImagesJob.new(image_ids: [1])
    # Simulate the 8th (last) attempt: retry_on counts per-exception
    # executions in exception_executions (incremented on rescue), while
    # the alert message reports the overall executions counter.
    job.executions = 7 # perform_now increments to 8
    job.exception_executions = { "[TransferImagesJob::UploadFailure]" => 7 }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts { job.perform_now }

      assert_equal(1, alerts.size)
      assert_instance_of(JobAlert, alerts.first)
      assert_includes(alerts.first.message,
                      "Transfer failed for 1 file(s) after 8 attempts")
      assert_includes(alerts.first.message,
                      "TransferImagesJob.perform_now(image_ids: [1])")
      assert_no_enqueued_jobs(only: TransferImagesJob)
    end
  end

  # A stuck image (derivative sizes never generated -- processing died,
  # #4974) is not retried: another transfer attempt can't help it. It is
  # alerted with the reprocess remedy instead.
  def test_alerts_with_reprocess_command_for_stuck_images
    result = { uploaded: [], deleted: [], completed: [],
               failed: [], stuck: [5] }

    Image::Processor.stub(:transfer_images, result) do
      alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [5])
      end

      assert_equal(1, alerts.size)
      assert_includes(alerts.first.message, "processing died?")
      assert_includes(alerts.first.message,
                      Image::Processor.reprocess_command([5]))
      assert_no_enqueued_jobs(only: TransferImagesJob)
    end
  end

  # When a run has both stuck and failed entries, the UploadFailure
  # retries re-run the whole job -- but the stuck state can't change
  # between retries, so only the first execution alerts it (Copilot
  # review on PR #4977).
  def test_does_not_re_alert_stuck_images_on_retry_executions
    result = { uploaded: [], deleted: [], completed: [],
               failed: [[1, :remote1, "640/1.jpg"]], stuck: [5] }

    Image::Processor.stub(:transfer_images, result) do
      first_run_alerts = capture_alerts do
        TransferImagesJob.perform_now(image_ids: [1, 5])
      end
      assert_equal(1, first_run_alerts.size,
                   "first execution should alert the stuck image")
      assert_includes(first_run_alerts.first.message, "processing died?")

      retry_run = TransferImagesJob.new(image_ids: [1, 5])
      retry_run.executions = 1 # perform_now increments to 2 (a retry)
      retry_alerts = capture_alerts { retry_run.perform_now }
      assert_empty(retry_alerts, "retries must not re-emit the stuck alert")
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
