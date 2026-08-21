# frozen_string_literal: true

require("test_helper")

class MiscDataRepairsJobTest < ActiveJob::TestCase
  # Each task delegates to a model class method that already has its own
  # dedicated test coverage (Synonym, Name::Spelling, Name::Format,
  # Observation, Occurrence, User). This job's own contract is that it
  # calls every task, forwards dry_run, and logs the aggregate result -
  # so stub each task rather than re-testing the underlying repair logic
  # here.
  def test_perform_runs_every_task_and_forwards_dry_run
    calls = []
    stub_tasks(calls) { MiscDataRepairsJob.perform_now(dry_run: true) }

    assert_equal(MiscDataRepairsJob::TASKS.map { |k, m, _d| [k, m, true] },
                 calls)
  end

  # Confirms the job actually integrates with the real model methods
  # (e.g. the :dry_run kwarg name matches every method's real signature) -
  # the stub-based test above can't catch a signature mismatch since it
  # fakes the call.
  def test_perform_runs_real_tasks_without_error
    MiscDataRepairsJob.perform_now(dry_run: true)
  end

  # A task that yields row-level failure messages (rows it could not
  # repair) gets each one routed to ApplicationJob#alert.
  def test_row_level_failures_are_routed_to_alert
    alerts = []
    job = MiscDataRepairsJob.new
    fake = lambda { |dry_run:, &blk|
      blk&.call("Occurrence #1: repair failed (dry_run=#{dry_run})")
      []
    }
    job.stub(:alert, ->(msg) { alerts << msg }) do
      Occurrence.stub(:refresh_has_specimen_cache, fake) do
        job.perform(dry_run: true)
      end
    end

    assert_equal(1, alerts.size)
    assert_match(/Occurrence #1: repair failed/, alerts.first)
  end

  private

  def stub_tasks(calls, tasks = MiscDataRepairsJob::TASKS, &block)
    return yield if tasks.empty?

    klass, method, = tasks.first
    fake = lambda { |dry_run:|
      calls << [klass, method, dry_run]
      []
    }
    klass.stub(method, fake) { stub_tasks(calls, tasks[1..], &block) }
  end
end
