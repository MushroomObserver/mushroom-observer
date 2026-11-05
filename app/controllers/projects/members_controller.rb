# frozen_string_literal: true

#  ==== Manage Project Members
#  new::
#  create:: (add member)
#  edit::
#  update:: (change_member_status)

module Projects
  # CRUD for project members
  class MembersController < ApplicationController
    include Projects::TabCountsRefreshable
    include Projects::AddableObservations

    before_action :login_required

    def index
      return unless find_project!

      users = @project.user_group.users.includes(:image).to_a
      render(Views::Controllers::Projects::Members::Index.new(
               project: @project, users: users, user: @user
             ))
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

      users =
        User.where.not(verified: nil).order(last_login: :desc).limit(100).to_a
      render(Views::Controllers::Projects::Members::New.new(
               project: @project, users: users, user: @user
             ))
    end

    def create
      return unless find_project!

      candidates = resolved_candidates
      unless @project.is_admin?(@user) || self_only_open_join?(candidates)
        return must_be_project_admin!(@project.id)
      end

      if candidates.any?
        candidates.each { |user| set_status(@project, :member, user, :add) }
      else
        flash_error(:project_members_not_found.t)
      end

      respond_to do |format|
        format.turbo_stream { render_create_response }
        format.html { return_to_caller(@project, params[:target]) }
      end
    end

    # Form to make a given User either a member or an admin.
    # Linked from: show_project, add_users, admin_request email
    # Inputs:
    #   params[:project_id] (was :id)
    #   params[:candidate]
    #   params[:commit]
    # Outputs: @project, @project_member
    # Posts to same action.  Redirects to show_project when done.
    # def change_member_status
    def edit
      return unless find_project!
      return unless find_project_member!
      if @project.is_admin?(@user) || @user == @project_member.user
        return render_member_edit_form
      end

      must_be_project_admin!(@project.id)
    end

    def update
      return unless find_project!
      return unless find_project_member!
      unless @project.is_admin?(@user) || @user == @project_member.user
        return must_be_project_admin!(@project.id)
      end

      update_membership(@project, @project_member.user)
    end

    # Turbo-stream modal showing how many of the candidate's observations
    # match current project constraints and aren't already in the project.
    # See issue #4129.
    def add_obs_modal
      return unless find_project!
      return unless find_project_member!
      unless @project.member?(@user) && @user == @project_member.user
        return must_be_project_admin!(@project.id)
      end

      count = addable_observations(@project, @project_member.user).count
      respond_to do |format|
        format.turbo_stream do
          render(Views::Controllers::Projects::Members::AddObsModal.new(
                   project: @project,
                   candidate: @project_member.user,
                   count: count,
                   batch_limit: self.class.add_obs_batch_limit
                 ), layout: false)
        end
      end
    end

    # Turbo-stream modal with three radio buttons for setting the
    # current user's trust_level on this project. See issue #4148.
    def trust_modal
      return unless find_project!
      return unless find_project_member!

      allowed = @project.member?(@user) && @user == @project_member.user
      return must_be_project_admin!(@project.id) unless allowed

      respond_to do |format|
        format.turbo_stream do
          render(Components::Modal.new(
                   type: :turbo_form, identifier: "trust_settings",
                   title: :show_project_trust_settings_title.l(
                     project: @project.title
                   ),
                   user: @user,
                   model: @project_member.user,
                   form_class:
                     Views::Controllers::Projects::Members::TrustSettings,
                   form_locals: {
                     project: @project,
                     current_trust_level:
                       @project_member.trust_level || "no_trust"
                   }
                 ), layout: false)
        end
      end
    end

    private

    def render_member_edit_form
      render(Views::Controllers::Projects::Members::Edit.new(
               project: @project,
               project_member: @project_member,
               user: @user
             ))
    end

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id].to_s)
    end

    def find_project_member!
      user = find_or_goto_index(User, params[:candidate])
      return unless user

      @project_member = @project.project_members.find_by(user: user) ||
                        ProjectMember.new(project: @project, user: user)
    end

    # A single flat `candidate` param (Members::New's per-row Add
    # button, or a bookmarked link) resolves to at most one user; the
    # inline AddForm widget on the members index submits a
    # namespaced, newline/comma-separated list that can resolve to
    # several -- same shape as the project's other add-target widgets
    # (TargetNames/TargetLocations).
    def resolved_candidates
      return [find_member(params[:candidate])].compact if params[:candidate]

      raw = params.dig(:project_members_add, :candidates).to_s
      raw.split(/[,\n]/).filter_map { |entry| find_member(entry.strip) }
    end

    def self_only_open_join?(candidates)
      @project.open_membership && candidates == [@user]
    end

    # The batch-add widget is the only turbo_stream caller whose page
    # carries the #project_members_widget/#project_members_table
    # targets this replaces -- the per-row Add button on the "new"
    # page and the Join button on the project summary page also post
    # here, turbo-enabled, from pages that don't have those ids, so
    # they fall back to the redirect instead.
    def render_create_response
      if params[:project_members_add]
        render_members_update
      else
        return_to_caller(@project, params[:target])
      end
    end

    def render_members_update
      users = @project.user_group.users.includes(:image).to_a
      render(turbo_stream: [
               turbo_stream.replace(
                 "project_members_widget",
                 Views::Controllers::Projects::Members::AddForm.new(
                   project: @project
                 )
               ),
               turbo_stream.replace(
                 "project_members_table",
                 Views::Controllers::Projects::Members::Tables.new(
                   project: @project, users: users, user: @user
                 )
               ),
               turbo_stream_admin_subtabs("members"),
               turbo_stream_flash_update
             ])
    end

    def return_to_caller(project, target)
      if target == "project_index"
        redirect_to(project_path(project.id))
      else
        redirect_to(project_members_path(project.id, q: q_param))
      end
    end

    def find_member(str)
      return User.safe_find(str) if str.to_s.match?(/^\d+$/)

      User.lookup_unique_text_name(str)
    end

    def update_membership(project, candidate)
      unless update_trust_status(project, candidate)
        unless update_admin_status(project, candidate)
          return must_be_project_admin!(project.id)
        end

        update_member_status(project, candidate)
      end
      return_to_caller(project, params[:target])
    end

    def update_trust_status(project, candidate)
      if params[:commit] == :change_member_status_revoke_trust.l
        flash_notice(:change_member_status_revoke_trust_flash.l)
        set_trust(project, candidate, "no_trust")
        true
      elsif params[:commit] == :change_member_hidden_gps_trust.l
        flash_notice(:change_member_hidden_gps_trust_flash.l)
        set_trust(project, candidate, "hidden_gps")
        true
      elsif params[:commit] == :change_member_editing_trust.l
        flash_notice(:change_member_editing_trust_flash.l)
        set_trust(project, candidate, "editing")
        true
      elsif params[:commit] == :change_member_add_obs.l
        count = add_observations(project, candidate)
        flash_notice(:change_member_add_obs_flash.t(count: count))
        true
      else
        false
      end
    end

    def set_trust(project, user, trust_level)
      member = project.project_members.find_by(user:)
      member.update(trust_level:)
    end

    def update_admin_status(project, candidate)
      make_admin = (params[:commit] == :change_member_status_make_admin.l)
      if project.is_admin?(@user)
        set_status(project, :admin, candidate, make_admin)
      elsif make_admin
        return false
      end
      true
    end

    def update_member_status(project, candidate)
      make_member = [
        :change_member_status_make_admin.l,
        :change_member_status_make_member.l
      ].member?(params[:commit])
      set_status(project, :member, candidate, make_member)
    end

    def must_be_project_admin!(id)
      flash_error(:change_member_status_denied.t)
      redirect_to(project_members_path(id, q: q_param))
    end

    # Add/remove a given User to/from a given UserGroup.
    # Changes should get logged
    def set_status(project, type, user, add)
      update_project_membership(project, type, user, add)
      group = project.send(type == :member ? :user_group : :admin_group)
      if add
        set_status_add(project, type, user, group)
      else
        set_status_remove(project, type, user, group)
      end
    end

    def update_project_membership(project, type, user, add)
      project_member = ProjectMember.find_by(project:, user:)
      unless project_member
        project_member = ProjectMember.create(project:, user:,
                                              trust_level: "editing")
        flash_notice(:add_members_with_editing.l)
      end
      return unless project_member
      return if type == :admin || add

      project_member.destroy
    end

    def set_status_add(project, type, user, group)
      if group.users.include?(user)
        flash_notice(:"add_members_already_added_#{type}".t(user: user.login))
      else
        group.users << user unless group.users.member?(user)
        project.send(:"log_add_#{type}", user)
        flash_notice(:"add_members_added_#{type}".t(user: user.login))
      end
    end

    def set_status_remove(project, type, user, group)
      if group.users.include?(user)
        group.users.delete(user)
        project.send(:"log_remove_#{type}", user)
        flash_notice(:"add_members_removed_#{type}".t(user: user.login))
      else
        flash_notice(:"add_members_already_removed_#{type}".t(user: user.login))
      end
    end
  end
end
