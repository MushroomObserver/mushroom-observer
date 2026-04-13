# frozen_string_literal: true

# Called by deploy.sh to check for running background jobs.
# Prints job details to stdout if any jobs are running; prints nothing
# if no jobs are running.
#
# Usage: bundle exec rails runner script/check_running_jobs.rb

claimed = SolidQueue::ClaimedExecution.includes(:job).all
exit if claimed.empty?

def format_duration(total_seconds)
  hours, remainder = total_seconds.divmod(3600)
  minutes, seconds = remainder.divmod(60)
  format("%dh %02dm %02ds", hours, minutes, seconds)
end

def inat_import_id(job)
  args = job.arguments["arguments"]
  gid = args&.first
  return nil unless gid.is_a?(Hash)

  global_id = gid["_aj_globalid"]
  return nil unless global_id

  global_id.split("/").last.to_i
end

def inat_remaining_time(import, elapsed)
  remaining = import.total_expected_time - elapsed
  [remaining.to_i, 0].max
rescue StandardError
  nil
end

def inat_import_line(import, elapsed_str, remaining_str)
  base = "InatImportJob: user=#{import.user&.login} " \
         "inat_user=#{import.inat_username} " \
         "progress=#{import.imported_count}/#{import.importables} " \
         "elapsed=#{elapsed_str}"
  remaining_str ? "#{base} remaining=~#{remaining_str}" : base
end

def inat_import_details(job, elapsed_str)
  import_id = inat_import_id(job)
  return nil unless import_id

  import = InatImport.find_by(id: import_id)
  return nil unless import

  elapsed = (Time.zone.now - job.created_at).to_i
  remaining = inat_remaining_time(import, elapsed)
  remaining_str = format_duration(remaining) if remaining&.positive?
  inat_import_line(import, elapsed_str, remaining_str)
end

claimed.each do |ce|
  job = ce.job
  class_name = job.class_name
  elapsed = (Time.zone.now - job.created_at).to_i
  elapsed_str = format_duration(elapsed)

  if class_name == "InatImportJob"
    details = inat_import_details(job, elapsed_str)
    if details
      puts(details)
      next
    end
  end

  puts("#{class_name}: elapsed=#{elapsed_str}")
end
