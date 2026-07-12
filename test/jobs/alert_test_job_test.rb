# frozen_string_literal: true

require("test_helper")

class AlertTestJobTest < ActiveJob::TestCase
  def test_alert_mode_sends_a_unique_message
    alerts = capture_alerts { AlertTestJob.perform_now(mode: "alert") }

    assert_equal(1, alerts.size)
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "alert-path")
  end

  # repeat mode must produce the SAME message every run, so error_grouping
  # can collapse a burst - that is the whole point of the mode.
  def test_repeat_mode_sends_a_constant_message
    first = capture_alerts { AlertTestJob.perform_now(mode: "repeat") }
    second = capture_alerts { AlertTestJob.perform_now(mode: "repeat") }

    assert_equal(AlertTestJob::REPEAT_MESSAGE, first.first.message)
    assert_equal(first.first.message, second.first.message)
  end

  def test_raise_mode_raises
    assert_raises(RuntimeError) { AlertTestJob.perform_now(mode: "raise") }
  end

  private

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
