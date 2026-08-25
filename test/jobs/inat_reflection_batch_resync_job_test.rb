# frozen_string_literal: true

require("test_helper")

class InatReflectionBatchResyncJobTest < ActiveJob::TestCase
  # The scheduled batch runs off the :maintenance pool, like the other
  # daily housekeeping jobs (config/recurring.yml).
  def test_enqueues_on_the_maintenance_queue
    assert_enqueued_with(job: InatReflectionBatchResyncJob,
                         queue: "maintenance") do
      InatReflectionBatchResyncJob.perform_later
    end
  end

  # The job is a thin wrapper: it drives Inat::ReflectionBatchResyncer and
  # carries no triggering user (sync is admin-owned, #4215).
  def test_perform_delegates_to_the_batch_resyncer
    called = false
    fake = Object.new
    fake.define_singleton_method(:resync_all) do
      called = true
      { synced: 0 }
    end
    fake.define_singleton_method(:back_link_alerts) { [] }

    Inat::ReflectionBatchResyncer.stub(:new, ->(**) { fake }) do
      InatReflectionBatchResyncJob.perform_now
    end

    assert(called, "the job should run the batch resyncer")
  end

  # A back-link mismatch collected during the run is routed to #alerts.
  def test_back_link_alerts_are_sent_to_alerts
    fake = Object.new
    fake.define_singleton_method(:resync_all) { { synced: 0 } }
    fake.define_singleton_method(:back_link_alerts) do
      ["Reflection obs 1: Mushroom Observer URL field mismatch"]
    end

    alerts = capture_alerts do
      Inat::ReflectionBatchResyncer.stub(:new, ->(**) { fake }) do
        InatReflectionBatchResyncJob.perform_now
      end
    end

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message, "Mushroom Observer URL field")
  end

  private

  # Records exceptions handed to the #alerts pipeline while alerting is
  # forced active (mirrors the helper in the other job tests).
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
