# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(project_id, start, count)
    project = Project.find(project_id)
    raise("No Project with id=#{project_id}") unless project

    prefix = project.field_slip_prefix || "MOTEST"
    icon = "public/logo-120.png" # Will be replaced with project.logo
    filename = "tmp/#{prefix}-#{Time.now.to_i}.pdf"
    view = FieldSlipView.new(project.title, prefix, icon, start, count)
    view.render
    view.save_as(filename)
    filename
  end

  def create_pdf(filename, title, prefix, icon, start, count)
    
  end
end
