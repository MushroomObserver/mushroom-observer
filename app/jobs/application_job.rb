# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no
  # longer available discard_on ActiveJob::DeserializationError

  def log(str)
    time = Time.zone.now.to_s
    log_entry = "#{time}: #{self.class.name} #{arguments.join(" ")} #{str}\n"
    open("log/job.log", "a") do |f|
      f.write(log_entry)
    end
  end
end
