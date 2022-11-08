# frozen_string_literal: true

#
#  = Project Controller
#
#  == Actions
#   L = login required
#   A = admin required
#   V = has view
#   P = prefetching allowed
#
#  ==== Index
#  list_projects::
#  project_search::
#  index_project::
#  show_selected_projects::  (helper)
#
#  ==== Show, Create, Edit
#  show_project::
#  next_project::
#  prev_project::
#  add_project::
#  edit_project::
#  destroy_project::
#
#  ==== Manage
#  admin_request::
#  add_members::
#  change_member_status::
#  set_status::              (helper)
#
################################################################################

class ProjectController < ApplicationController
  before_action :login_required
  # except: [
  #   :index_project,
  #   :list_projects,
  #   :next_project,
  #   :prev_project,
  #   :project_search,
  #   :show_project
  # ]

  before_action :disable_link_prefetching, except: [
    :admin_request,
    :edit_project,
    :show_project
  ]

  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  # Show list of selected projects, based on current Query.
  def index_project
    query = find_or_create_query(:Project, by: params[:by])
    show_selected_projects(query, id: params[:id].to_s, always_index: true)
  end

  # Show list of latest projects.  (Linked from left panel.)
  def list_projects
    query = create_query(:Project, :all, by: :title)
    show_selected_projects(query)
  end

  # Display list of Project's whose title or notes match a string pattern.
  def project_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (project = Project.safe_find(pattern))
      redirect_to(action: "show_project", id: project.id)
    else
      query = create_query(:Project, :pattern_search, pattern: pattern)
      show_selected_projects(query)
    end
  end

  # Show selected list of projects.
  def show_selected_projects(query, args = {})
    args = {
      action: :list_projects,
      letters: "projects.title",
      num_per_page: 50,
      include: :user
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_title.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t]
    ]

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show, Create, Edit
  #
  ##############################################################################

  # Display project by itself.
  # Linked from: observations/show, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  def show_project
    store_location
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))

    @canonical_url = "#{MO.http_domain}/project/show_project/#{@project.id}"
    @is_member = @project.is_member?(@user)
    @is_admin = @project.is_admin?(@user)
    @drafts = NameDescription.
              joins(:admin_groups).
              where("name_description_admins.user_group_id":
                    @project.admin_group_id).
              includes(:name, :user)
  end

  # Go to next project: redirects to show_project.
  def next_project
    redirect_to_next_object(:next, Project, params[:id].to_s)
  end

  # Go to previous project: redirects to show_project.
  def prev_project
    redirect_to_next_object(:prev, Project, params[:id].to_s)
  end

  # Form to create a project.
  # Linked from: list_projects
  # Inputs:
  #   params[:id] (project id)
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders add_project again.
  #   Outputs: @project
  def add_project
    pass_query_params
    if request.method == "GET"
      @project = Project.new
    else
      title = params[:project][:title].to_s
      project = Project.find_by_title(title)
      user_group = UserGroup.find_by_name(title)
      admin_name = "#{title}.admin"
      admin_group = UserGroup.find_by_name(admin_name)
      if title.blank?
        flash_error(:add_project_need_title.t)
      elsif project
        flash_error(:add_project_already_exists.t(title: project.title))
      elsif user_group
        flash_error(:add_project_group_exists.t(group: title))
      elsif admin_group
        flash_error(:add_project_group_exists.t(group: admin_name))
      else
        # Create members group.
        user_group = UserGroup.new
        user_group.name = title
        user_group.users << @user

        # Create admin group.
        admin_group = UserGroup.new
        admin_group.name = admin_name
        admin_group.users << @user

        # Create project.
        @project = Project.new(whitelisted_project_params)
        @project.user = @user
        @project.user_group = user_group
        @project.admin_group = admin_group

        if !user_group.save
          flash_object_errors(user_group)
        elsif !admin_group.save
          flash_object_errors(admin_group)
        elsif !@project.save
          flash_object_errors(@project)
        else
          @project.log_create
          flash_notice(:add_project_success.t)
          redirect_with_query(action: :show_project, id: @project.id)
        end
      end
    end
  end

  # Form to edit a project
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  #   params[:project][:title]
  #   params[:project][:summary]
  # Success:
  #   Redirects to show_project.
  # Failure:
  #   Renders edit_project again.
  #   Outputs: @project
  def edit_project
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))

    if !check_permission!(@project)
      redirect_with_query(action: "show_project", id: @project.id)
    elsif request.method == "POST"
      @title = params[:project][:title].to_s
      @summary = params[:project][:summary]
      if @title.blank?
        flash_error(:add_project_need_title.t)
      elsif (project2 = Project.find_by_title(@title)) &&
            (project2 != @project)
        flash_error(:add_project_already_exists.t(title: @title))
      elsif !@project.update(whitelisted_project_params)
        flash_object_errors(@project)
      else
        @project.log_update
        flash_notice(:runtime_edit_project_success.t(id: @project.id))
        redirect_with_query(action: "show_project", id: @project.id)
      end
    end
  end

  # Callback to destroy a project.
  # Linked from: show_project, observations/show
  # Redirects to observations/show.
  # Inputs: params[:id]
  # Outputs: none
  def destroy_project
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))

    if !check_permission!(@project)
      redirect_with_query(action: "show_project", id: @project.id)
    elsif !@project.destroy
      flash_error(:destroy_project_failed.t)
      redirect_with_query(action: "show_project", id: @project.id)
    else
      @project.log_destroy
      flash_notice(:destroy_project_success.t)
      redirect_with_query(action: :index_project)
    end
  end

  ##############################################################################
  #
  #  :section: Manage
  #
  ##############################################################################

  # Form to compose email for the admins
  # Linked from: show_project
  # Inputs:
  #   params[:id]
  # Outputs:
  #   @project
  # Posts to the same action.  Redirects back to show_project.
  def admin_request
    sender = @user
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))
    return unless request.method == "POST"

    subject = params[:email][:subject]
    content = params[:email][:content]
    @project.admin_group.users.each do |receiver|
      AdminMailer.build(sender, receiver, @project,
                        subject, content).deliver_now
    end
    flash_notice(:admin_request_success.t(title: @project.title))
    redirect_with_query(action: :show_project, id: @project.id)
  end

  # View that lists all users with links to add each as a member.
  # Linked from: show_project (for admins only)
  # Inputs:
  #   params[:id]
  #   params[:candidate]  (when click on user)
  # Outputs:
  #   @project, @users
  # "Posts" to the same action.  Stays on this view until done.
  def add_members
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))
    return must_be_project_admin!(@project.id) unless @project.is_admin?(@user)

    @users = User.order("last_login desc").limit(100).to_a
    return unless (@candidate = params[:candidate])

    add_member(@candidate, @project)
  end

  def add_member(str, project)
    if (user = find_member(str))
      set_status(project, :member, user, :add)
      @candidate = nil
    else
      flash_error(:add_members_not_found.t(str))
    end
  end

  def find_member(str)
    return User.safe_find(str) if str.to_s.match?(/^\d+$/)

    User.find_by(login: str.to_s.sub(/ <.*>$/, ""))
  end

  # Form to make a given User either a member or an admin.
  # Linked from: show_project, add_users, admin_request email
  # Inputs:
  #   params[:id]
  #   params[:candidate]
  #   params[:commit]
  # Outputs: @project, @candidate
  # Posts to same action.  Redirects to show_project when done.
  def change_member_status
    pass_query_params
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))
    return unless (@candidate = find_or_goto_index(User, params[:candidate]))
    return must_be_project_admin!(@project.id) unless @project.is_admin?(@user)
    return unless request.method == "POST"

    post_change_member_status(@project, @candidate)
  end

  def post_change_member_status(project, candidate)
    admin = member = :remove
    case params[:commit]
    when :change_member_status_make_admin.l
      admin = member = :add
    when :change_member_status_make_member.l
      member = :add
    end
    set_status(project, :admin, candidate, admin)
    set_status(project, :member, candidate, member)
    redirect_with_query(action: :show_project, id: project.id)
  end

  def must_be_project_admin!(id)
    flash_error(:change_member_status_denied.t)
    redirect_with_query(action: :show_project, id: id)
  end

  # Add/remove a given User to/from a given UserGroup.
  # TODO: Changes should get logged
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

  ##############################################################################

  private

  def whitelisted_project_params
    params.require(:project).permit(:title, :summary)
  end
end
