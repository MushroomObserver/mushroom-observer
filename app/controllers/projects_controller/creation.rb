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

  # Exact/reverse-name match only -- Project has no bounding-box UI of
  # its own, so (unlike Observation/SpeciesList) it can never build a
  # brand new Location inline. A clean but unmatched name falls through
  # to a post-save redirect to Locations::New instead (see
  # finalize_saved_project); a dubious one blocks the save and asks the
  # user to confirm via @dubious_where_reasons, same as everywhere else
  # Locationable's dubious_where_reasons_for is used.
  def find_location(where)
    location = Location.find_by_name_or_reverse_name(where)
    return location if location || where == ""

    @dubious_where_reasons = dubious_where_reasons_for(where,
                                                       param_key: :project)
    nil
  end

  def create_project(title, admin_name, where)
    user_group = create_members_group(title)
    admin_group = create_admin_group(admin_name)
    location = find_location(where)

    if @dubious_where_reasons.blank? && user_group && admin_group
      save_new_project(user_group, admin_group, location, where)
    else
      cleanup_failed_project_creation(user_group, admin_group, where)
    end
  end

  def save_new_project(user_group, admin_group, location, where)
    @project = build_new_project(user_group, admin_group, location)
    upload_image_if_present
    return finalize_saved_project(where) if @project.save

    flash_object_errors(@project)
    cleanup_failed_project_creation(user_group, admin_group, where)
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

  def finalize_saved_project(where)
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
    if @project.location.nil? && where.present?
      redirect_to(new_location_path(where:, set_project: @project.id))
    else
      redirect_to(project_path(@project.id))
    end
  end

  # Rebuilds @project from what was actually submitted (project_params
  # includes :place_name) rather than a blank Project.new, so a
  # dubious-location reload shows the user's entered title/summary/etc
  # back instead of an empty form (the literal #2248 complaint).
  #
  # Project#place_name= only ever resolves-or-clears +location+ (see
  # app/models/project.rb) -- it has no free-text fallback the way
  # Observation/SpeciesList's place_name does, so the just-submitted,
  # still-unresolved text can't be read back off @project itself.
  # @raw_place_name carries it explicitly for the visible autocompleter
  # and the approved_where hidden field (see Views::Controllers::
  # Projects::Form).
  def cleanup_failed_project_creation(user_group, admin_group, where)
    admin_group&.destroy
    user_group&.destroy
    @project = Project.new(project_params)
    @project_dates_any = true
    @raw_place_name = where
    image_ivars
    render_new_form
  end
end
