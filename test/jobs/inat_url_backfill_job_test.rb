# frozen_string_literal: true

require("test_helper")

# What the job runs, and what a human hears about. The walk itself is
# covered by Inat::URLBackfillTest.
class InatURLBackfillJobTest < ActiveJob::TestCase
  # Stands in for Inat::URLBackfill, returning a canned result.
  class FakeBackfill
    def initialize(result)
      @result = result
    end

    def call = @result
  end

  def setup
    @result = build_result(counts: { checked: 3, rewritten: 1 })
  end

  def build_result(counts: {}, alerts: [], complete: false)
    Inat::URLBackfill::Result.new(counts: counts, cursor: 42, alerts: alerts,
                                  complete: complete)
  end

  # Captures every #alerts message the job sends.
  def capture_alerts(**args)
    sent = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(
        :notify_exception, ->(exception, **_opts) { sent << exception.message }
      ) { run_job(**args) }
    end
    sent
  end

  def run_job(**args)
    Inat::URLBackfill::Client.stub(:configured?, true) do
      Inat::URLBackfill.stub(:new, ->(**) { FakeBackfill.new(@result) }) do
        InatURLBackfillJob.perform_now(**args)
      end
    end
  end

  # The recurring entry ships before the token is installed on the
  # server, and stays until someone retires the pass; neither should be
  # a nightly failure.
  def test_does_nothing_without_a_configured_token
    built = false
    Inat::URLBackfill::Client.stub(:configured?, false) do
      Inat::URLBackfill.stub(:new, ->(**) { built = true }) do
        InatURLBackfillJob.perform_now
      end
    end

    assert_not(built, "no credential means no walk")
  end

  def test_passes_its_budget_to_the_backfill
    seen = nil
    Inat::URLBackfill::Client.stub(:configured?, true) do
      Inat::URLBackfill.stub(
        :new,
        lambda { |**kwargs|
          seen = kwargs[:budget]
          FakeBackfill.new(@result)
        }
      ) do
        InatURLBackfillJob.perform_now(time_limit: 5.minutes, max_writes: 20)
      end
    end

    assert_equal(5.minutes, seen.time_limit)
    assert_equal(20, seen.max_writes)
  end

  def test_says_nothing_on_an_ordinary_run
    assert_empty(capture_alerts)
  end

  # Engine messages get the same treatment the scheduled batch gives
  # them (InatReflectionBatchResyncJob).
  def test_forwards_engine_alerts
    @result = build_result(alerts: ["obs 5: photo not imported"])

    assert_includes(capture_alerts, "obs 5: photo not imported")
  end

  # One message, not one per failure: distinct texts are distinct Slack
  # posts.
  def test_reports_rejected_writes_once_per_run
    @result = build_result(counts: { write_failed: 7 })

    sent = capture_alerts

    assert_equal(1, sent.size)
    assert_match(/7 field value writes rejected/, sent.first)
  end

  # The nag that ends the pass, repeating daily until someone acts.
  def test_asks_to_be_retired_when_the_pass_is_complete
    @result = build_result(complete: true)

    assert_match(/pass complete.*recurring\.yml/m, capture_alerts.first)
  end
end
