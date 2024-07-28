# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(tracker_id)
    log("Starting FieldSlipJob.perform(#{tracker_id})")
    cleanup_old_pdfs(tracker_id)
    tracker = FieldSlipJobTracker.find(tracker_id)
    raise(:field_slip_job_no_tracker.t) unless tracker

    tracker.processing
    icon = "public/logo-120.png"
    view = FieldSlipView.new(tracker, icon)
    view.render
    view.save_as(tracker.filepath)
    tracker.done
    log("Done with FieldSlipJob.perform(#{tracker_id})")
    tracker.filepath
  end

  private

  MAX_JOB_AGE = 1.week

  def cleanup_old_pdfs(tracker_id)
    FieldSlipJobTracker.where.not(id: tracker_id).find_each do |tracker|
      next unless tracker.updated_at < Time.zone.now - MAX_JOB_AGE

      if File.exist?(tracker.filepath)
        File.delete(tracker.filepath)
        log("Deleted #{tracker.filepath}")
      else
        log("#{tracker.filepath} does not exist")
      end
      log("Destroying #{FieldSlipJobTracker.first.serializable_hash}")
      tracker.destroy
    end
  end

  def log(str)
    time = Time.zone.now.to_s
    log_entry = "#{time}: #{str}\n"
    open("log/job.log", "a") do |f|
      f.write(log_entry)
    end
  end
end
