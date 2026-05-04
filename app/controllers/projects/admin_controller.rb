# frozen_string_literal: true

# Admin tab landing page for a project. Houses Edit/Delete and the
# Members/Aliases configuration links. Project-admins only.
module Projects
  class AdminController < ApplicationController
    before_action :login_required

    def show
      return unless find_project!
      return must_be_project_admin!(@project.id) unless
        @project.is_admin?(@user)

      render(Views::Controllers::Projects::Admin::Show.new(
               project: @project, user: @user
             ), layout: true)
    end

    def controller_model_name
      "Project"
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def must_be_project_admin!(id)
      flash_error(:change_member_status_denied.t)
      redirect_to(project_path(id))
    end
  end
end
