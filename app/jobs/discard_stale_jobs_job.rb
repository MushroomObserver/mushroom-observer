# frozen_string_literal: true
class DiscardStaleJobsJob < ApplicationJob
  queue_as :default

  def perform
    discard_date = 5.months.ago.in_time_zone("UTC")
    connect_to(mushroomobserver) # connect to mission_control

    discard_stale_failed_jobs(discard_date)
  end

  def discard_stale_failed_jobs(discard_date)
    count = ActiveJobs.jobs.failed.count
    return unless count.positive?

    ActiveJob.jobs.failed.each do |job|
      job.discard if job.failed_at < discard_date
    end
    discarded = count - ActiveJobs.jobs.failed.count
    puts("Discarded #{discarded} jobs which failed before #{discard_date}")
  end
end
