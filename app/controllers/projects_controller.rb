# frozen_string_literal: true

class ProjectsController < ApplicationController
  include Validators

  before_action :login_required
  before_action :pass_query_params, except: [:index]

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Projects.default_order # :updated_at
  end

  # ApplicationController uses this to dispatch #index to a private method
  def index_active_params
    [:pattern, :member, :by].freeze
  end

  # Display list of projects with a given member, sorted by date.
  def member
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:member].to_s,
      index_path: projects_path
    )
    return unless user

    query = create_query(:Project, members: user)
    [query, {}]
  end

  def index_display_opts(opts, _query)
    { letters: true,
      num_per_page: 50,
      include: :user }.merge(opts)
  end

  public ####################################################################

  # Display project by itself.
  # Linked from: observations/show, list_projects
  # Inputs: params[:id] (project)
  # Outputs: @project
  def show
    store_location
    return if find_project_and_where!.blank?

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
    image_ivars
    @project = Project.new
    @project_dates_any = true
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
    image_ivars
    return unless find_project_and_where!

    @start_date_fixed = @project.start_date.present?
    @end_date_fixed = @project.end_date.present?
    @project_dates_any = !@start_date_fixed && !@end_date_fixed
    return if check_permission!(@project)

    redirect_to(project_path(@project.id))
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
    elsif ProjectConstraints.new(params).ends_before_start?
      flash_error(:add_project_ends_before_start.t)
    elsif user_group
      flash_error(:add_project_group_exists.t(group: title))
    elsif admin_group
      flash_error(:add_project_group_exists.t(group: admin_name))
    else
      return create_project(title, admin_name, params[:project][:place_name])
    end
    @project = Project.new(project_params)
    @project_dates_any = params[:project][:dates_any].downcase == "true"
    image_ivars
    render(:new, location: new_project_path)
  end

  def update
    return unless find_project_and_where!

    unless check_permission!(@project)
      return redirect_to(project_path(@project.id))
    end

    upload_image_if_present
    @summary = params[:project][:summary]
    @field_slip_prefix = params[:project][:field_slip_prefix]
    if valid_title && valid_where && valid_dates
      if @project.update(project_create_params)
        override_fixed_dates
        @project.save
        @project.log_update
        flash_notice(:runtime_edit_project_success.t(id: @project.id))
        return redirect_to(project_path(@project.id))
      else
        flash_object_errors(@project)
      end
    end
    image_ivars
    render(:edit, location: edit_project_path(@project.id))
  end

  # Callback to destroy a project.
  # Linked from: show_project, observations/show
  # Redirects to observations/show.
  # Inputs: params[:id]
  # Outputs: none
  # def destroy_project
  def destroy
    return unless find_project_and_where!

    if !check_permission!(@project)
      redirect_to(project_path(@project.id))
    elsif !@project.destroy
      flash_error(:destroy_project_failed.t)
      redirect_to(project_path(@project.id))
    else
      @project.log_destroy
      flash_notice(:destroy_project_success.t)
      redirect_to(projects_path(q: get_query_param))
    end
  end

  private ############################################################

  def project_params
    params.require(:project).permit(
      :open_membership, :title, :summary, :field_slip_prefix, :place_name,
      :location_id,
      :"start_date(1i)", :"start_date(2i)", :"start_date(3i)",
      :"end_date(1i)", :"end_date(2i)", :"end_date(3i)"
    )
  end

  def image_ivars
    @licenses = License.available_names_and_ids(@user.license)

    (@copyright_holder, @copyright_year, @upload_license_id) =
      if @project&.image
        [@project.image.copyright_holder, @project.image.when.year,
         @project.image.license.id]
      else
        [@user.legal_name, Time.zone.now.year, @user.license&.id]
      end
  end

  def set_ivars_for_show
    @canonical_url = "#{MO.http_domain}/projects/#{@project.id}"
    @is_member = @project.member?(@user)
    @is_admin = @project.is_admin?(@user)
    @drafts = NameDescription.joins(:admin_groups).
              where("name_description_admins.user_group_id":
                    @project.admin_group_id).
              includes(:name, :user)
    # Save a lookup in comments_for_object
    @comments = @project.comments&.sort_by(&:created_at)&.reverse
    # Matches for the list-search autocompleter
    @object_names = @project.observations.joins(:name).
                    select(Name[:text_name], Name[:id]).distinct.
                    order(Name[:text_name])
  end

  def upload_image_if_present
    # Check if we need to upload an image.
    upload = params.dig(:upload, :image)
    return if upload.blank?

    image = upload_image(upload, params[:upload][:copyright_holder],
                         params[:upload][:license_id],
                         params[:upload][:copyright_year])
    return unless image

    @project.image = image
  end

  ##############################################################################
  #
  #  :section: update, edit private methods
  #
  ##############################################################################

  def project_create_params
    params.require(:project).
      permit(:title, :summary, :open_membership, :field_slip_prefix,
             "start_date(1i)", "start_date(2i)", "start_date(3i)",
             "end_date(1i)", "end_date(2i)", "end_date(3i)")
  end

  def find_project_and_where!
    @project = Project.show_includes.safe_find(params[:id].to_s) ||
               flash_error_and_goto_index(Project, params[:id].to_s)

    @where = @project&.location&.display_name || ""
  end

  def create_members_group(title)
    user_group = UserGroup.new
    user_group.name = title
    user_group.users << @user
    return user_group if user_group.save

    flash_object_errors(user_group)
    nil
  end

  def create_admin_group(admin_name)
    admin_group = UserGroup.new
    admin_group.name = admin_name
    admin_group.users << @user
    return admin_group if admin_group.save

    flash_object_errors(admin_group)
    nil
  end

  def find_location(where)
    location = Location.find_by_name_or_reverse_name(where)
    return location if location || where == ""

    flash_warning(:add_project_no_location.t(where: where))
    nil
  end

  def create_project(title, admin_name, where)
    user_group = create_members_group(title)
    admin_group = create_admin_group(admin_name)
    location = find_location(where)
    if user_group && admin_group && (location || (where == ""))
      @project = Project.new(project_create_params)
      @project.user = @user
      @project.user_group = user_group
      @project.admin_group = admin_group
      @project.location = location
      if ProjectConstraints.new(params).allow_any_dates?
        @project.start_date = @project.end_date = nil
      end

      upload_image_if_present
      if @project.save
        ProjectMember.create!(project: @project, user: @user,
                              trust_level: "hidden_gps")
        @project.log_create
        flash_notice(:add_project_success.t)
        return redirect_to(project_path(@project.id))
      else
        flash_object_errors(@project)
      end
    end
    admin_group&.destroy
    user_group&.destroy
    @project = Project.new
    image_ivars
    render(:new, location: new_project_path)
  end

  def override_fixed_dates
    @project.start_date = nil if params[:project][:dates_any] == "true" ||
                                 params.dig(:start_date, :fixed) == "false"
    @project.end_date = nil if params[:project][:dates_any] == "true" ||
                               params.dig(:end_date, :fixed) == "false"
  end
end
