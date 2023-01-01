module Projects
  # request to be a project admin
  class AdminRequestsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # Form to compose email for the admins
    # Linked from: show_project
    # Inputs:
    #   params[:project_id] (was :id)
    # Outputs:
    #   @project
    # def admin_request
    def new
      return unless find_project!
    end

    # Redirects back to show_project.
    def create
      sender = @user
      return unless find_project!

      subject = params[:email][:subject]
      content = params[:email][:content]
      @project.admin_group.users.each do |receiver|
        AdminMailer.build(sender, receiver, @project,
                          subject, content).deliver_now
      end
      flash_notice(:admin_request_success.t(title: @project.title))
      redirect_to(project_path(@project.id, q: get_query_param))
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end
  end
end
