# frozen_string_literal: true

require("test_helper")

class ApplicationJobTest < ActiveJob::TestCase
  # Minimal job that always fails, to exercise ApplicationJob's rescue_from.
  class FailingJob < ApplicationJob
    def perform
      raise(ArgumentError.new("boom"))
    end
  end

  # When a notifier is registered (e.g. production), a failing job reports to
  # ExceptionNotifier and still re-raises so SolidQueue records the failure.
  def test_failure_is_reported_and_reraised_when_alerting_active
    reported = nil
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             ->(exception, **_opts) { reported = exception }) do
        error = assert_raises(ArgumentError) { FailingJob.perform_now }
        assert_equal("boom", error.message)
      end
    end
    assert_instance_of(ArgumentError, reported,
                       "Job failure should be reported to ExceptionNotifier")
  end

  # With no notifier registered (dev/test/CI gating) it must not notify, but
  # must still re-raise.
  def test_failure_reraises_without_notifying_when_alerting_off
    notified = false
    ExceptionNotifier.stub(:notifiers, []) do
      ExceptionNotifier.stub(:notify_exception, ->(*) { notified = true }) do
        assert_raises(ArgumentError) { FailingJob.perform_now }
      end
    end
    assert_not(notified, "Should not notify when no notifier is registered")
  end
end
