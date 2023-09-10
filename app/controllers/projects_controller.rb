# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :login_required
  # disable cop because index is defined in ApplicationController
  before_action :pass_query_params, except: [:index] # rubocop:disable Rails/LexicallyScopedActionFilter

  # index::
  # ApplicationController uses this to dispatch #index to a private method
  @index_subaction_param_keys = [
    :pattern,
    :by,
    :member
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results
  }.freeze

  # Display project by itself.
  # Linked from: observations/show, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  # def show_project
  def show
    store_location
    return unless (@project = find_or_goto_index(Project, params[:id].to_s))

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Project, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, Project, params[:id]) and return
    end

    set_ivars_for_show
  end

  ##############################################################################

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
  # def add_project
  def new
    @project = Project.new
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
  # def edit_project
  def edit
    return unless find_project!

    return if check_permission!(@project)

    redirect_to(project_path(@project.id, q: get_query_param))
  end

  def create
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
      return create_project(title, admin_name)
    end
    render(:new, location: new_project_path(q: get_query_param))
  end

  def update
    return unless find_project!

    unless check_permission!(@project)
      return redirect_to(project_path(@project.id, q: get_query_param))
    end

    @title = params[:project][:title].to_s
    @summary = params[:project][:summary]
    if @title.blank?
      flash_error(:add_project_need_title.t)
    elsif (project2 = Project.find_by_title(@title)) &&
          (project2 != @project)
      flash_error(:add_project_already_exists.t(title: @title))
    elsif !@project.update(permitted_project_params)
      flash_object_errors(@project)
    else
      @project.log_update
      flash_notice(:runtime_edit_project_success.t(id: @project.id))
      return redirect_to(project_path(@project.id, q: get_query_param))
    end
    render(:edit, location: edit_project_path(@project.id, q: get_query_param))
  end

  # Callback to destroy a project.
  # Linked from: show_project, observations/show
  # Redirects to observations/show.
  # Inputs: params[:id]
  # Outputs: none
  # def destroy_project
  def destroy
    return unless find_project!

    if !check_permission!(@project)
      redirect_to(project_path(@project.id, q: get_query_param))
    elsif !@project.destroy
      flash_error(:destroy_project_failed.t)
      redirect_to(project_path(@project.id, q: get_query_param))
    else
      @project.log_destroy
      flash_notice(:destroy_project_success.t)
      redirect_to(projects_path(q: get_query_param))
    end
  end

  private ############################################################

  def set_ivars_for_show
    @canonical_url = "#{MO.http_domain}/projects/#{@project.id}"
    @is_member = @project.is_member?(@user)
    @is_admin = @project.is_admin?(@user)
    @drafts = NameDescription.joins(:admin_groups).
              where("name_description_admins.user_group_id":
                    @project.admin_group_id).
              includes(:name, :user)
  end

  ############ Index private methods
  def default_index_subaction
    list_all
  end

  # Show list of latest projects.  (Linked from left panel.)
  def list_all
    query = create_query(:Project, :all, by: default_sort_order)
    show_selected_projects(query)
  end

  def default_sort_order
    ::Query::ProjectBase.default_order
  end

  # Show list of selected projects, based on current Query.
  def index_query_results
    query = find_or_create_query(:Project, by: params[:by])
    show_selected_projects(query, id: params[:id].to_s, always_index: true)
  end

  # Display list of Project's whose title or notes match a string pattern.
  def pattern
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (@project = Project.safe_find(pattern))
      # redirect_to(action: :show, id: project.id)
      set_ivars_for_show
      render("show", location: project_path(@project.id))
    else
      query = create_query(:Project, :pattern_search, pattern: pattern)
      show_selected_projects(query)
    end
  end

  # Display list of projects with a given member, sorted by date.
  def member
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:member].to_s,
      index_path: projects_path
    )
    return unless user

    query = create_query(:Project, :all, member: user)
    show_selected_projects(query)
  end

  # Show selected list of projects.
  def show_selected_projects(query, args = {})
    args = {
      action: :index,
      letters: "projects.title",
      num_per_page: 50,
      include: :user
    }.merge(args)

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: update, edit private methods
  #
  ##############################################################################

  def permitted_project_params
    params.require(:project).permit(:title, :summary, :open_membership,
                                    :accepting_observations)
  end

  def find_project!
    @project = find_or_goto_index(Project, params[:id].to_s)
  end

  def create_project(title, admin_name)
    # Create members group.
    user_group = UserGroup.new
    user_group.name = title
    user_group.users << @user

    # Create admin group.
    admin_group = UserGroup.new
    admin_group.name = admin_name
    admin_group.users << @user

    # Create project.
    @project = Project.new(permitted_project_params)
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
      redirect_to(project_path(@project.id, q: get_query_param))
    end
  end
end
