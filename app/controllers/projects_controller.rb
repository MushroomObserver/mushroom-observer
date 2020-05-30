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

class ProjectsController < ApplicationController
  before_action :login_required, except: [
    :index,
    :index_project,
    :list_projects, # aliased
    :next_project, # aliased
    :prev_project, # aliased
    :project_search,
    :show,
    :show_next,
    :show_prev,
    :show_project # aliased
  ]

  before_action :disable_link_prefetching, except: [
    :admin_request,
    :edit,
    :edit_project, # aliased
    :show,
    :show_project # aliased
  ]

  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  # Show list of selected projects, based on current Query.
  def index_project # :norobots:
    query = find_or_create_query(
      :Project,
      by: params[:by]
    )
    show_selected_projects(
      query,
      id: params[:id].to_s,
      always_index: true
    )
  end

  # Show list of latest projects.  (Linked from left panel.)
  def index
    query = create_query(
      :Project,
      :all,
      by: :title
    )
    show_selected_projects(query)
  end

  alias_method :list_projects, :index

  # Display list of Project's whose title or notes match a string pattern.
  def project_search # :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (@project = Project.safe_find(pattern))
      # redirect_to(
      #   action: :show,
      #   id: @project.id
      # )
      redirect_to_project
    else
      query = create_query(:Project, :pattern_search, pattern: pattern)
      show_selected_projects(query)
    end
  end

  # Show selected list of projects.
  def show_selected_projects(query, args = {})
    args = {
      action: :index,
      letters: "projects.title",
      num_per_page: 50
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
  # Linked from: show_observation, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  def show # :prefetch:
    store_location
    pass_query_params
    if @project = find_or_goto_index(Project, params[:id].to_s)
      @canonical_url = "#{MO.http_domain}/project/show_project/#{@project.id}"
      @is_member = @project.is_member?(@user)
      @is_admin = @project.is_admin?(@user)

      @draft_data = Project.connection.select_all %(
        SELECT n.display_name, nd.id, nd.user_id
        FROM names n, name_descriptions nd, name_descriptions_admins nda
        WHERE nda.user_group_id = #{@project.admin_group_id}
          AND nd.id = nda.name_description_id
          AND n.id = nd.name_id
        ORDER BY n.sort_name ASC, n.author ASC
      )
      @draft_data = @draft_data.to_a
    end
  end

  alias_method :show_project, :show

  # Go to next project: redirects to show_project.
  def show_next # :norobots:
    redirect_to_next_object(:next, Project, params[:id].to_s)
  end

  alias_method :next_project, :show_next

  # Go to previous project: redirects to show_project.
  def show_prev # :norobots:
    redirect_to_next_object(:prev, Project, params[:id].to_s)
  end

  alias_method :prev_project, :show_prev

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

  def new # :norobots:
    pass_query_params
    @project = Project.new
  end

  alias_method :add_project, :new

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
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
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
  def edit # :prefetch: :norobots:
    pass_query_params
    return unless @project = find_or_goto_index(Project, params[:id].to_s)

    if !check_permission!(@project)
      # redirect_with_query(
      #   action: :show,
      #   id: @project.id
      # )
      redirect_to_project_with_query
    end
  end

  alias_method :edit_project, :edit

  def update
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
      # redirect_with_query(
      #   action: :show,
      #   id: @project.id
      # )
      redirect_to_project_with_query
    end
  end

  # Callback to destroy a project.
  # Linked from: show_project, show_observation
  # Redirects to show_observation.
  # Inputs: params[:id]
  # Outputs: none
  def destroy # :norobots:
    pass_query_params
    if @project = find_or_goto_index(Project, params[:id].to_s)
      if !check_permission!(@project)
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
      elsif !@project.destroy
        flash_error(:destroy_project_failed.t)
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
      else
        @project.log_destroy
        flash_notice(:destroy_project_success.t)
        # redirect_with_query(
        #   action: :index
        # )
        redirect_to_project_index_with_query
      end
    end
  end

  alias_method :destroy_project, :destroy

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
  def admin_request # :prefetch: :norobots:
    sender = @user
    pass_query_params
    if @project = find_or_goto_index(Project, params[:id].to_s)
      if request.method == "POST"
        subject = params[:email][:subject]
        content = params[:email][:content]
        for receiver in @project.admin_group.users
          AdminEmail.build(sender, receiver, @project,
                           subject, content).deliver_now
        end
        flash_notice(:admin_request_success.t(title: @project.title))
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
      end
    end
  end

  # View that lists all users with links to add each as a member.
  # Linked from: show_project (for admins only)
  # Inputs:
  #   params[:id]
  #   params[:candidate]  (when click on user)
  # Outputs:
  #   @project, @users
  # "Posts" to the same action.  Stays on this view until done.
  def add_members # :norobots:
    pass_query_params
    if @project = find_or_goto_index(Project, params[:id].to_s)
      @users = User.where.not(verified: nil).order("login, name").to_a
      if !@project.is_admin?(@user)
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
      elsif params[:candidate].present?
        @candidate = User.find(params[:candidate])
        set_status(@project, :member, @candidate, :add)
      end
    end
  end

  # Form to make a given User either a member or an admin.
  # Linked from: show_project, add_users, admin_request email
  # Inputs:
  #   params[:id]
  #   params[:candidate]
  #   params[:commit]
  # Outputs: @project, @candidate
  # Posts to same action.  Redirects to show_project when done.
  def change_member_status # :norobots:
    pass_query_params
    if (@project = find_or_goto_index(Project, params[:id].to_s)) &&
       (@candidate = find_or_goto_index(User, params[:candidate]))
      if !@project.is_admin?(@user)
        flash_error(:change_member_status_denied.t)
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to_project_with_query
      elsif request.method == "POST"
        user_group = @project.user_group
        admin_group = @project.admin_group
        admin = member = :remove
        case params[:commit]
        when :change_member_status_make_admin.l
          admin = member = :add
        when :change_member_status_make_member.l
          member = :add
        end
        set_status(@project, :admin, @candidate, admin)
        set_status(@project, :member, @candidate, member)
        # redirect_with_query(
        #   action: :show,
        #   id: @project.id
        # )
        # redirect_to_referer || redirect_to_project_index
        redirect_to_project_with_query
      end
    end
  end

  # Add/remove a given User to/from a given UserGroup.
  # TODO: Changes should get logged
  def set_status(project, type, user, mode)
    group = project.send(type == :member ? :user_group : :admin_group)
    if mode == :add
      unless group.users.include?(user)
        group.users << user unless group.users.member?(user)
        project.send("log_add_#{type}", user)
      end
    else
      if group.users.include?(user)
        group.users.delete(user)
        project.send("log_remove_#{type}", user)
      end
    end
  end

  ##############################################################################

  private

  def whitelisted_project_params
    params.require(:project).permit(:title, :summary)
  end

  # borrowed from herbaria_controller:
  def redirect_to_referer
    return false if @back.blank?

    redirect_to(@back)
    true
  end

  def redirect_to_project
    redirect_to project_path(@project.id)
  end

  def redirect_to_project_with_query
    redirect_to project_path(@project.id, q: get_query_param)
  end

  def redirect_to_project_index_with_query(project = @project)
    # redirect_with_query(
    #   action: :index,
    #   id: project.try(&:id)
    # )
    redirect_to projects_path(id: project.try(&:id), q: get_query_param)
  end

end
