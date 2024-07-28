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
      @field_slip_max = field_slip_max
    end

    def create
      return unless find_project!
      return unless ok_field_slip_count

      tracker = FieldSlipJobTracker.create(
        prefix: @project.field_slip_prefix,
        start: @project.next_field_slip,
        title: @project.title,
        user: User.current,
        one_per_page: params[:one_per_page] == "1",
        count: field_slips
      )
      if tracker
        update_project(tracker)
      else
        flash_error(:field_slips_tracker_fail.t(title: @project.title))
      end
    end

    private

    def update_project(tracker)
      @project.next_field_slip = tracker.last + 1
      if @project.save
        FieldSlipJob.perform_later(tracker.id)
        flash_notice(:field_slips_created_job.t(filename: tracker.filename))
      else
        tracker.destroy
        flash_error(:field_slips_project_update_fail.t(title: @project.title))
      end
      # redirect_to(project_url(@project))
      respond_to do |format|
        # Append a new row to the table of field slip jobs
        format.turbo_stream do
          render(turbo_stream: turbo_stream.prepend(
            :field_slip_job_trackers, # the id of the div to append to
            partial: "projects/field_slips/tracker_row",
            locals: { tracker: tracker }
          ))
        end
        format.html
      end
    end

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def field_slips
      @field_slips ||= params[:field_slips].to_i
    end

    def field_slip_max
      @field_slip_max ||= if @project.is_admin?(User.current)
                            12_000
                          elsif @project.member?(User.current)
                            60
                          else
                            0
                          end
    end

    def ok_field_slip_count
      return true if field_slip_max.positive? && field_slips <= field_slip_max

      if field_slip_max.zero?
        flash_error(:field_slips_must_be_member.t)
      else
        flash_error(:field_slips_too_many_field_slips.t(max: field_slip_max))
      end
      redirect_to(new_project_field_slip_path(project_id: @project.id))
      false
    end
  end
end
