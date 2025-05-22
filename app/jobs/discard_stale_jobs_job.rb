# frozen_string_literal: true

require "mission_control/jobs"

class DiscardStaleJobsJob < ApplicationJob
  queue_as :default

  def perform(discard_date = 1.week.ago.in_time_zone("UTC"))
    discard_stale_finished_jobs(discard_date)
    # discard_stale_failed_jobs(discard_date)
  end

  def discard_stale_failed_jobs(discard_date)
    count = ActiveJobs.jobs.failed.count
    return unless count.positive?

    ActiveJob.jobs.failed.each do |job|
      job.discard if job.failed_at < discard_date
    end
    discarded = count - ActiveJobs.jobs.failed.count
    log("Discarded #{discarded} jobs which failed before #{discard_date}")
  end

  def discard_stale_finished_jobs(discard_date)
    before_count = SolidQueue::Job.finished.count

    SolidQueue::Job.clear_finished_in_batches(finished_before: discard_date)

    discarded = before_count - SolidQueue::Job.finished.count
    log("Discarded #{discarded} jobs which finshed before #{discard_date}")
  end
end
