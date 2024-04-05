# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(project_id, tracker_id)
    project = Project.find(project_id)
    raise(:field_slip_job_no_project.t(id: project_id)) unless project

    tracker = FieldSlipJobTracker.find(tracker_id)
    raise(:field_slip_job_no_tracker.t(id: tracker_id)) unless tracker

    tracker.processing
    icon = "public/logo-120.png" # Will be replaced with project.logo
    view = FieldSlipView.new(project.title, tracker.prefix, icon,
                             tracker.start, tracker.count)
    view.render
    view.save_as(tracker.filename)
    tracker.done
    tracker.filename
  end
end
