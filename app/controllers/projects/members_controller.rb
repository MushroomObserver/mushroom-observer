# frozen_string_literal: true

#  ==== Manage Project Memberss
#  new::
#  create:: (add member)
#  edit::
#  update:: (change_member_status)

module Projects
  # CRUD for project members
  class MembersController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def index
      return unless find_project!

      @users = @project.user_group.users
    end

    # View that lists all verified users with links to add each as a member.
    # Linked from: show_project (for admins only)
    # Inputs:
    #   params[:project_id] (was :id)
    #   params[:candidate]  (when click on user)
    # Outputs:
    #   @project, @users
    # "Posts" to the same action.  Stays on this view until done.
    def new
      return unless find_project!
      unless @project.is_admin?(@user)
        return must_be_project_admin!(@project.id)
      end

      @users =
        User.where.not(verified: nil).order(last_login: :desc).limit(100).to_a
    end

    def create
      return unless find_project!
      unless @project.is_admin?(@user) ||
             (@project.open_membership && @user.id.to_s == params[:candidate])
        return must_be_project_admin!(@project.id)
      end
      return unless (@candidate = params[:candidate])

      add_member(@candidate, @project)
    end

    # Form to make a given User either a member or an admin.
    # Linked from: show_project, add_users, admin_request email
    # Inputs:
    #   params[:project_id] (was :id)
    #   params[:candidate]
    #   params[:commit]
    # Outputs: @project, @candidate
    # Posts to same action.  Redirects to show_project when done.
    # def change_member_status
    def edit
      return unless find_project!
      return unless find_candidate!
      return if @project.is_admin?(@user) || @user == @candidate

      must_be_project_admin!(@project.id)
    end

    def update
      return unless find_project!
      return unless find_candidate!
      unless @project.is_admin?(@user) || @user == @candidate
        return must_be_project_admin!(@project.id)
      end

      update_member_status(@project, @candidate)
    end

    private

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def find_candidate!
      @candidate = find_or_goto_index(User, params[:candidate])
    end

    # Redirects back to show_project.
    def add_member(str, project)
      if (user = find_member(str))
        set_status(project, :member, user, :add)
        @candidate = nil
      else
        flash_error(:add_members_not_found.t(str))
      end
      return_to_caller(project, params[:target])
    end

    def return_to_caller(project, target)
      if target == "project_index"
        redirect_to(project_path(project.id, q: get_query_param))
      else
        redirect_to(project_members_path(project.id, q: get_query_param))
      end
    end

    def find_member(str)
      return User.safe_find(str) if str.to_s.match?(/^\d+$/)

      User.find_by(login: str.to_s.sub(/ <.*>$/, ""))
    end

    # Redirects back to show_project.
    def update_member_status(project, candidate)
      admin = member = :remove
      case params[:commit]
      when :change_member_status_make_admin.l
        unless project.is_admin?(@user)
          return must_be_project_admin!(project.id)
        end

        admin = member = :add
      when :change_member_status_make_member.l
        member = :add
      end
      if project.is_admin?(@user)
        set_status(project, :admin, candidate,
                   admin)
      end
      set_status(project, :member, candidate, member)
      return_to_caller(project, params[:target])
    end

    def must_be_project_admin!(id)
      flash_error(:change_member_status_denied.t)
      redirect_to(project_members_path(id, q: get_query_param))
    end

    # Add/remove a given User to/from a given UserGroup.
    # Changes should get logged
    def set_status(project, type, user, mode)
      group = project.send(type == :member ? :user_group : :admin_group)
      set_status_add(project, type, user, group) if mode == :add
      set_status_remove(project, type, user, group) if mode == :remove
    end

    def set_status_add(project, type, user, group)
      if group.users.include?(user)
        flash_notice(:"add_members_already_added_#{type}".t(user: user.login))
      else
        group.users << user unless group.users.member?(user)
        project.send("log_add_#{type}", user)
        flash_notice(:"add_members_added_#{type}".t(user: user.login))
      end
    end

    def set_status_remove(project, type, user, group)
      if group.users.include?(user)
        group.users.delete(user)
        project.send("log_remove_#{type}", user)
        flash_notice(:"add_members_removed_#{type}".t(user: user.login))
      else
        flash_notice(:"add_members_already_removed_#{type}".t(user: user.login))
      end
    end
  end
end
