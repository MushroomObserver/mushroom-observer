# frozen_string_literal: true

require "mission_control/jobs"

class DiscardStaleJobsJob < ApplicationJob
  queue_as :default

  def perform(discard_date = 1.week.ago.in_time_zone("UTC"))
    discard_stale_failed_jobs(discard_date)
    discard_stale_finished_jobs
  end

  def discard_stale_failed_jobs(discard_date)
    # Solid Queue does not have a failed or failed_at column.
    # Instead it tracks failed jobs using the finished_at column
    # and a related failed executions table
    old_failed_executions =
      SolidQueue::FailedExecution.where(created_at: ...discard_date)
    return if old_failed_executions.none?

    old_failed_count = SolidQueue::FailedExecution.count

    old_failed_executions.each do |failed_execution|
      job = SolidQueue::Job.find_by(id: failed_execution.job_id)
      job&.destroy
      failed_execution.destroy
    end

    discarded = old_failed_count - SolidQueue::FailedExecution.count
    log("Discarded #{discarded} jobs which failed before #{discard_date}")
  end

  def discard_stale_finished_jobs
    before_count = SolidQueue::Job.finished.count

    SolidQueue::Job.clear_finished_in_batches

    discard_date =
      Time.zone.now -
      Rails.application.config.solid_queue.clear_finished_jobs_after
    discarded = before_count - SolidQueue::Job.finished.count
    log("Discarded #{discarded} jobs which finished before #{discard_date}")
  end
end
