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
      @page_max = page_max
    end

    def create
      return unless find_project!
      return unless ok_page_count

      tracker = FieldSlipJobTracker.create(prefix: @project.field_slip_prefix,
                                           start: @project.next_field_slip,
                                           count: 6 * pages)
      if tracker
        @project.next_field_slip = tracker.last + 1
        if @project.save
          FieldSlipJob.perform_later(@project.id, tracker.id)
          flash_notice(:field_slips_created_job.t(filename: tracker.filename))
        else
          tracker.destroy
          flash_error(:field_slips_project_update_fail.t(title: @project.title))
        end
      else
        flash_error(:field_slips_tracker_fail.t(title: @project.title))
      end
      # redirect_to(project_url(@project))
      respond_to do |format|
        # Append a new row to the table of field slip jobs
        format.turbo_stream do
          render(turbo_stream: turbo_stream.append(
            :field_slip_jobs, # the id of the div to append to
            partial: "projects/field_slips/tracker_row",
            locals: { tracker: tracker }
          ))
        end
      end
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def pages
      @pages ||= params[:pages].to_i
    end

    def page_max
      @page_max ||= if @project.is_admin?(User.current)
                      2000
                    elsif @project.member?(User.current)
                      10
                    else
                      0
                    end
    end

    def ok_page_count
      return true if page_max.positive? && pages <= page_max

      if page_max.zero?
        flash_error(:field_slips_must_be_member.t)
      else
        flash_error(:field_slips_too_many_pages.t(max: page_max))
      end
      redirect_to(new_project_field_slip_path(project_id: @project.id))
      false
    end
  end
end