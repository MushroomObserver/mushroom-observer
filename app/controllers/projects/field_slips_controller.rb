# frozen_string_literal: true

#  ==== Manage Project Field Slips
#  new:: Allow new job to be created
#  create:: Create field slip print job

module Projects
  class FieldSlipsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def new
      flash_error(:field_slip_no_project.t) unless find_project!
    end

    def create
      return unless find_project!

      filename = "tmp/#{@project.field_slip_prefix}-#{Time.now.to_i}.pdf"
      start = @project.next_field_slip
      @project.next_field_slip = start + 6
      if @project.save
        FieldSlipJob.perform_later(@project.id, start, 6, filename)
        flash_notice(:field_slips_created_job.t(filename:))
      else
        flash_error(:field_slips_project_update_fail.t(title: project.title))
      end
      redirect_to(project_url(@project))
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end
  end
end
