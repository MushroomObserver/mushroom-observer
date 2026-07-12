# frozen_string_literal: true

require("test_helper")

class ApplicationJobTest < ActiveJob::TestCase
  # Minimal job that always fails, to exercise ApplicationJob's rescue_from.
  class FailingJob < ApplicationJob
    def perform
      raise(ArgumentError.new("boom"))
    end
  end

  # Minimal job that just reports what it saw in Textile's cache when it
  # started, to exercise ApplicationJob's before_perform reset. A plain
  # class-instance-variable (not `@@`) is fine here -- this class has no
  # subclasses.
  class ReportsTextileCacheJob < ApplicationJob
    class << self
      attr_accessor :seen_name_lookup
    end

    def perform
      self.class.seen_name_lookup = Textile.name_lookup.dup
    end
  end

  # Minimal job that emits a review-worthy alert, to exercise
  # ApplicationJob#alert.
  class AlertingJob < ApplicationJob
    def perform
      alert("review this", extra: "ctx")
    end
  end

  # Regression test for #4741/#4772: mailer jobs never run through
  # ApplicationController's before_action, so without ApplicationJob's
  # own reset, a job dispatched to a Solid Queue worker thread right
  # after another job registered a name on that same thread would see
  # the leftover Textile cache instead of starting clean.
  def test_resets_textile_cache_before_each_job
    Textile.register_name(names(:agaricus))

    ReportsTextileCacheJob.perform_now

    assert_equal({}, ReportsTextileCacheJob.seen_name_lookup,
                 "Job should start with a clean Textile name-lookup " \
                 "cache, not one leaked from prior work on this thread")
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

  # #alert routes review-worthy output to the notifier (Slack in prod) as a
  # JobAlert carrying the job's identity, when alerting is active.
  def test_alert_notifies_with_job_alert_when_alerting_active
    reported = nil
    opts_seen = nil
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **opts|
                               reported = exception
                               opts_seen = opts
                             }) do
        AlertingJob.perform_now
      end
    end
    assert_instance_of(JobAlert, reported)
    assert_equal("review this", reported.message)
    assert_equal("ApplicationJobTest::AlertingJob", opts_seen[:data][:job])
    assert_equal("ctx", opts_seen[:data][:extra])
    assert(opts_seen[:data].key?(:job_id), "alert should carry the job_id")
  end

  # With no notifier registered, #alert stays log-only and does not notify.
  def test_alert_is_log_only_when_alerting_off
    notified = false
    ExceptionNotifier.stub(:notifiers, []) do
      ExceptionNotifier.stub(:notify_exception, ->(*) { notified = true }) do
        AlertingJob.perform_now
      end
    end
    assert_not(notified, "alert must not notify when no notifier registered")
  end
end
