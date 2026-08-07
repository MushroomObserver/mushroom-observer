# frozen_string_literal: true

# Project-creation helpers extracted from `ProjectsController#create`.
# Covers the new project's two `UserGroup`s, its location lookup,
# building / saving the project record, and the post-save and
# rollback paths.
module ProjectsController::Creation
  private

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

    if project_groups_ok?(user_group, admin_group, location, where)
      @project = build_new_project(user_group, admin_group, location)
      upload_image_if_present
      return finalize_saved_project if @project.save

      flash_object_errors(@project)
    end

    cleanup_failed_project_creation(user_group, admin_group)
  end

  def project_groups_ok?(user_group, admin_group, location, where)
    user_group && admin_group && (location || where == "")
  end

  def build_new_project(user_group, admin_group, location)
    project = Project.new(project_create_params)
    project.user = @user
    project.user_group = user_group
    project.admin_group = admin_group
    project.location = location
    if ProjectConstraints.new(params).allow_any_dates?
      project.start_date = project.end_date = nil
    end
    project
  end

  def finalize_saved_project
    # Same trust the add-member and field-slip paths grant, and said out
    # loud for the same reason: someone setting a project up almost
    # always wants its admins able to work on the observations they put
    # in it, and being the creator should not make them the one admin
    # whose observations nobody else can touch.
    ProjectMember.create!(project: @project, user: @user,
                          trust_level: "editing")
    @project.log_create
    flash_notice(:add_project_success.t)
    flash_notice(:add_members_with_editing.l)
    redirect_to(project_path(@project.id))
  end

  def cleanup_failed_project_creation(user_group, admin_group)
    admin_group&.destroy
    user_group&.destroy
    @project = Project.new
    image_ivars
    render_new_form
  end
end
