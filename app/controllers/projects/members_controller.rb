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
    include Projects::MembershipStatusUpdates

    before_action :login_required

    def index
      return unless find_project!

      results = members_index_results
      render(Views::Controllers::Projects::Members::Index.new(
               project: @project, users: results[:users],
               pagination: results[:pagination], user: @user
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

    def members_index_results
      scope = Query.lookup(:User, member_of_project: @project.id,
                                  order_by: :login).scope.includes(:image)
      pagination = number_pagination_data
      pagination.num_total = scope.count
      users = scope.offset(pagination.from).limit(pagination.num_per_page).
              to_a
      { users: users, pagination: pagination }
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
      users = members_index_results[:users]
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

    def must_be_project_admin!(id)
      flash_error(:change_member_status_denied.t)
      redirect_to(project_members_path(id, q: q_param))
    end
  end
end
