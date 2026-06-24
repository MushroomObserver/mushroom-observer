# frozen_string_literal: true

require("test_helper")

class ApplicationJobTest < ActiveJob::TestCase
  # Minimal job that always fails, to exercise ApplicationJob's rescue_from.
  class FailingJob < ApplicationJob
    def perform
      raise(ArgumentError.new("boom"))
    end
  end

  # A failing job must (a) report to ExceptionNotifier and (b) still re-raise,
  # so SolidQueue records the failed execution.
  def test_failure_is_reported_and_reraised
    reported = nil
    ExceptionNotifier.stub(:notify_exception,
                           ->(exception, **_opts) { reported = exception }) do
      error = assert_raises(ArgumentError) { FailingJob.perform_now }
      assert_equal("boom", error.message)
    end
    assert_instance_of(ArgumentError, reported,
                       "Job failure should be reported to ExceptionNotifier")
  end
end
