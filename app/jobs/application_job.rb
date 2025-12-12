# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no
  # longer available discard_on ActiveJob::DeserializationError

  def log(str)
    time = Time.zone.now.to_s
    log_entry = "#{time}: #{self.class.name} #{arguments.join(" ")} #{str}\n"
    open(job_log_path, "a") do |f|
      f.write(log_entry)
    end
  end

  private

  def job_log_path
    # Use worker-specific log files in parallel testing to avoid conflicts
    if Rails.env.test? && (worker_num = IMAGE_CONFIG_DATA.database_worker_number)
      "log/job-#{worker_num}.log"
    else
      "log/job.log"
    end
  end
end
