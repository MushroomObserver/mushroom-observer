# frozen_string_literal: true

#  ==== Manage Project Field Slips
#  new:: Allow new job to be created
#  create:: Create field slip print job

module Projects
  class FieldSlipsController < ApplicationController
    PDF_DIR = "public/field_slips"

    before_action :login_required
    before_action :pass_query_params

    def new
      flash_error(:field_slip_no_project.t) unless find_project!
      @page_max = page_max
    end

    def create
      return unless find_project!
      return unless ok_page_count

      prefix = @project.field_slip_prefix
      FileUtils.mkdir_p(PDF_DIR)
      start = @project.next_field_slip
      count = 6 * pages
      last = start + count
      @project.next_field_slip = last
      filename = "#{PDF_DIR}/#{prefix}-" \
                 "#{code_num(start)}-#{code_num(last)}-" \
                 "#{Time.now.to_i}.pdf"
      if @project.save
        FieldSlipJob.perform_later(@project.id, start, count, filename)
        flash_notice(:field_slips_created_job.t(filename:))
      else
        flash_error(:field_slips_project_update_fail.t(title: @project.title))
      end
      redirect_to(project_url(@project))
    end

    private

    def code_num(num)
      num.to_s.rjust(5, "0")
    end

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def pages
      @pages ||= params[:pages].to_i
    end

    def page_max
      if @project.is_admin?(User.current)
        2000
      elsif @project.member?(User.current)
        10
      else
        1
      end
    end

    def ok_page_count
      return true if pages <= page_max

      flash_error(:field_slips_too_many_pages.t(max: page_max))
      redirect_to(new_project_field_slip_path(project_id: @project.id))
      return false
    end
  end
end
