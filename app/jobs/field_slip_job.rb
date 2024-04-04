# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(project_id, start, count, filename)
    project = Project.find(project_id)
    raise(:field_slip_job_no_project.t(id: project_id)) unless project

    prefix = project.field_slip_prefix || "MOTEST"
    icon = "public/logo-120.png" # Will be replaced with project.logo
    view = FieldSlipView.new(project.title, prefix, icon, start, count)
    view.render
    view.save_as(filename)
    filename
  end
end
