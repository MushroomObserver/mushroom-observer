# frozen_string_literal: true

# Site Admin self-promotion to Project Admin (issue #4145).
# A user with user.admin == true can promote themselves to Project Admin
# on any project, even one they are not currently a member of. The action
# adds them to admin_group + user_group, creates a ProjectMember row
# matching the default produced by the add-member flow, and emails the
# project owner.
module Projects
  class AdministrationsController < ApplicationController
    before_action :login_required

    def create
      return unless find_project!
      return must_be_site_admin! unless @user&.admin
      return already_admin! if @project.admin_group.users.include?(@user)

      @project.add_administrator(@user)
      notify_owner
      flash_notice(
        :project_administration_promoted_flash.l(title: @project.title)
      )
      redirect_to(project_path(@project.id))
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def must_be_site_admin!
      flash_error(:permission_denied.l)
      redirect_to(project_path(@project.id))
    end

    def already_admin!
      flash_warning(:project_administration_already_admin_flash.l)
      redirect_to(project_path(@project.id))
    end

    def notify_owner
      owner = @project.user
      return unless owner && owner != @user

      ProjectAdministrationMailer.build(
        site_admin: @user, project: @project, receiver: owner
      ).deliver_later
    end
  end
end
