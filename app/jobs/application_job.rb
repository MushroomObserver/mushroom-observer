# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no
  # longer available discard_on ActiveJob::DeserializationError

  # Textile::THREAD_KEYS's name-lookup cache is thread-local -- isolated
  # across concurrent job executions, but not auto-reset between
  # sequential jobs pooled onto the same Solid Queue worker thread.
  # Jobs never run through ApplicationController's before_action (its
  # own reset_textile_cache), so mailer jobs that call `.tp`/`.tl` on
  # translated text (e.g. NamingTrackerMailer, VerifyAccountMailer) can
  # otherwise pick up a leftover genus abbreviation left by a prior,
  # unrelated job on the same worker thread. See #3589, #4741.
  before_perform { Textile.clear_textile_cache }

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

  # Route review-worthy job output to the #alerts Slack channel (in
  # addition to the durable job.log record). Reuses the exception_
  # notification pipeline via a synthetic JobAlert, so it inherits the
  # same gating and de-duplication as crash notifications without
  # conflating with them. Notification happens only when ExceptionNotifier
  # has a registered notifier (production, or wherever NOTIFY_EXCEPTIONS
  # opts in - see config/initializers/exception_notification.rb);
  # otherwise it is log-only, and the job.log line still lands.
  # `job`/`job_id` are set last so caller context can't clobber the
  # alert's own identity.
  def alert(message, **context)
    log(message)
    return unless ExceptionNotifier.notifiers.any?

    ExceptionNotifier.notify_exception(
      JobAlert.new(message),
      data: { **context, job: self.class.name, job_id: job_id }
    )
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
