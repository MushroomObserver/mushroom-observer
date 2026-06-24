# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no
  # longer available discard_on ActiveJob::DeserializationError

  # Report background-job failures to the same place web errors go (Slack via
  # exception_notification), then re-raise so SolidQueue still records the
  # failed execution. The notifiers check keeps this in lockstep with the
  # initializer's gating (no notifier is registered outside production) without
  # duplicating its env logic. Subclass retry_on/discard_on handlers are
  # registered later and take precedence for the errors they cover.
  rescue_from(StandardError) do |exception|
    if ExceptionNotifier.notifiers.any?
      ExceptionNotifier.notify_exception(
        exception, data: { job: self.class.name, arguments: arguments }
      )
    end
    raise(exception)
  end

  def log(str)
    time = Time.zone.now.to_s
    log_entry = "#{time}: #{self.class.name} #{arguments.join(" ")} #{str}\n"
    File.open(job_log_path, "a") do |f|
      f.write(log_entry)
    end
  end

  private

  def job_log_path
    # Use worker-specific log files in parallel testing to avoid conflicts
    if Rails.env.test? &&
       (worker_num = IMAGE_CONFIG_DATA.database_worker_number)
      "log/job-#{worker_num}.log"
    else
      "log/job.log"
    end
  end
end
