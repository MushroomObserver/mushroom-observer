# frozen_string_literal: true

# Manage requests to be a project admin
module Projects
  class AdminRequestsController < ApplicationController
    before_action :login_required

    # Form to compose email for the admins
    # Linked from: show_project
    # Inputs:
    #   params[:project_id] (was :id)
    # Outputs:
    #   @project
    # def admin_request
    def new
      return unless find_project!

      render_admin_request_form
    end

    # Redirects back to show_project.
    # Migrated from QueuedEmail::ProjectAdminRequest to deliver_later.
    def create
      sender = @user
      return unless find_project!

      subject = params[:email][:subject]
      message = params[:email][:message]

      if message.blank?
        flash_error(:runtime_missing.t(field: :request_message.l))
        return render_admin_request_form
      end

      @project.admin_group.users.each do |receiver|
        ProjectAdminRequestMailer.build(
          sender:, receiver:, project: @project, subject:, message:
        ).deliver_later
      end
      flash_notice(:admin_request_success.t(title: @project.title))
      redirect_to(project_path(@project.id))
    end

    private

    def render_admin_request_form
      render(Views::Controllers::Projects::AdminRequests::New.new(
               project: @project
             ), layout: true)
    end

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end
  end
end
