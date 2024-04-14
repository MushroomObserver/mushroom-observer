# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(project_id, tracker_id)
    log("Starting FieldSlipJob.perform(#{project_id}, #{tracker_id})")
    cleanup_old_pdfs(tracker_id)
    project = Project.find(project_id)
    raise(:field_slip_job_no_project.t(id: project_id)) unless project

    tracker = FieldSlipJobTracker.find(tracker_id)
    raise(:field_slip_job_no_tracker.t(id: tracker_id)) unless tracker

    tracker.processing
    icon = "public/logo-120.png" # Will be replaced with project.logo
    view = FieldSlipView.new(project.title, tracker.prefix, icon,
                             tracker.start, tracker.count)
    view.render
    view.save_as(tracker.filepath)
    tracker.done
    log("Done with FieldSlipJob.perform(#{project_id}, #{tracker_id})")
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
