# frozen_string_literal: true

# Gracefully quiesce SolidQueue ahead of a restart / deploy:
#
#   1) Pause every queue so workers stop claiming NEW jobs.
#   2) Wait (up to a timeout) for in-flight (claimed) jobs to finish so the
#      queue flushes.
#
# The paused state lives in the DB (solid_queue_pauses) and PERSISTS across a
# supervisor restart, so once this script exits 0 it is safe to stop SolidQueue
# (and Puma) without interrupting a running job -- nothing is in flight. Jobs
# that were still queued (never claimed) stay put and run once you call
# script/resume_jobs.rb after the restart.
#
# The timeout here is a plain wall-clock deadline; it is unrelated to
# SolidQueue's own `shutdown_timeout` (that only applies when the supervisor is
# actually signalled, which happens later in the deploy, after this drain
# succeeds). On timeout the queues are LEFT PAUSED and we exit non-zero: in a
# deploy this runs before anything is stopped, so the site stays up, the stuck
# job keeps running, and the deploy aborts with the stuck job(s) reported.
#
# Works identically whether SolidQueue runs as a standalone service
# (`rake solid_queue:start`) or the Puma plugin (`rails s`): pausing and
# claiming are both coordinated through the database.
#
# Usage:
#   bundle exec rails runner script/pause_and_drain_jobs.rb [timeout_seconds]
#
# timeout_seconds defaults to 300 (5 minutes), overridable via the argument or
# $DRAIN_TIMEOUT.
#
# Exit codes:
#   0 - queues paused and drained (no claimed executions remain)
#   1 - timed out with jobs still running (queues remain paused)

TIMEOUT = Integer(ARGV.first || ENV.fetch("DRAIN_TIMEOUT", "300"))
POLL_SECONDS = 5

def format_duration(total_seconds)
  hours, remainder = total_seconds.divmod(3600)
  minutes, seconds = remainder.divmod(60)
  format("%dh %02dm %02ds", hours, minutes, seconds)
end

def queues_to_pause
  # Every queue that currently has jobs, plus "default" (all MO jobs use it),
  # so we still pause correctly when the tables are momentarily empty.
  (SolidQueue::Job.distinct.pluck(:queue_name).compact + ["default"]).uniq
end

def pause_all_queues
  queues_to_pause.each do |name|
    SolidQueue::Queue.find_by_name(name).pause
    puts("Paused queue: #{name}")
  end
end

def inat_import_id(job)
  global_id = job.arguments["arguments"]&.first
  return nil unless global_id.is_a?(Hash)

  gid = global_id["_aj_globalid"]
  gid && gid.split("/").last.to_i
end

# One human-readable line describing an in-flight job, with iNat import
# progress when we can identify it.
def job_line(claimed)
  job = claimed.job
  elapsed = format_duration((Time.zone.now - job.created_at).to_i)
  base = "#{job.class_name} (job ##{job.id}, running #{elapsed})"
  return base unless job.class_name == "InatImportJob"

  import = InatImport.find_by(id: inat_import_id(job))
  return base unless import

  "#{base} user=#{import.user&.login} " \
    "progress=#{import.imported_count}/#{import.total_importables}"
end

def report_in_flight(claimed, remaining)
  puts("#{claimed.size} job(s) still running; " \
       "#{format_duration(remaining)} before the deploy aborts:")
  claimed.each { |ce| puts("  - #{job_line(ce)}") }
end

# Poll until no jobs are claimed (return true) or the deadline passes
# (return false), reporting what's still in flight on each poll.
#
# `rails runner` runs with the ActiveRecord query cache ENABLED, which would
# serve the first poll's counts from cache on every subsequent iteration --
# the loop would never see the queue drain and would always time out. Wrap the
# loop in `uncached` so each poll hits the database.
def drain(deadline)
  ActiveRecord::Base.uncached do
    loop do
      claimed = SolidQueue::ClaimedExecution.includes(:job).to_a
      return true if claimed.empty?

      now = Time.zone.now
      return false if now >= deadline

      report_in_flight(claimed, (deadline - now).to_i)
      sleep(POLL_SECONDS)
    end
  end
end

pause_all_queues
puts("Waiting up to #{format_duration(TIMEOUT)} for in-flight jobs...")

if drain(Time.zone.now + TIMEOUT)
  puts("Queue flushed: no in-flight jobs remaining. Safe to stop SolidQueue.")
  exit(0)
end

stuck = ActiveRecord::Base.uncached do
  SolidQueue::ClaimedExecution.includes(:job).to_a
end
warn("Timed out after #{format_duration(TIMEOUT)} with " \
     "#{stuck.size} job(s) still running:")
stuck.each { |ce| warn("  - #{job_line(ce)}") }
warn("")
warn("The site is still up and queues stay PAUSED (no new jobs will start).")
warn("Resolve the stuck job(s), then resume with:")
warn("  bundle exec rails runner script/resume_jobs.rb")
exit(1)
