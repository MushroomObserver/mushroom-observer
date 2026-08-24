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

    Inat::ReflectionBatchResyncer.stub(:new, ->(**) { fake }) do
      InatReflectionBatchResyncJob.perform_now
    end

    assert(called, "the job should run the batch resyncer")
  end
end
