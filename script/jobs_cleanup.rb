#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("../config/boot")
require_relative("../config/environment")
include("mission_control")

# connect to mission_control
connect_to mushroomobserver

count = ActiveJobs.jobs.failed.count
if count.positive?
  discard_date = 5.months.ago.in_time_zone("UTC")
  ActiveJob.jobs.failed.each do |job|
    job.discard if job.failed_at < discard_date
  end
  discarded = count - ActiveJobs.jobs.failed.count
  puts("Discarded #{discarded} jobs which failed before #{discard_date}")
end

# DELETE ME
