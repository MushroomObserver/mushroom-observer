# frozen_string_literal: true

#  :section: Helpers
#
#    create_observation_object(...)     create rough first-drafts.
#
#    save_observation(...)              Save validated objects.
#
#    update_observation_object(...)     Update and save existing objects.
#
#    init_image()                       Handle image uploads.
#    create_image_objects(...)
#    update_good_images(...)
#    attach_good_images(...)

module ObservationsController::Validators
  private

  def validate_params(params)
    validate_name(params) &&
      validate_place_name(params) &&
      validate_projects(params)
  end

  def validate_name(params)
    given_name = param_lookup([:naming, :name], "").to_s
    chosen_name = param_lookup([:chosen_name, :name_id], "").to_s
    (success, @what, @name, @names, @valid_names, @parent_deprecated,
     @suggest_corrections) =
      Name.resolve_name(given_name, params[:approved_name], chosen_name)
    @naming.name = @name if @name
    success
  end

  def validate_place_name(params)
    success = true
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      success = false if @dubious_where_reasons != []
    end
    success
  end

  def validate_projects(params)
    return true if params[:project].empty? ||
                   params[:project][:ignore_proj_conflicts]

    @suspect_checked_projects = checked_project_conflicts
    @suspect_checked_projects.empty?
  end

  def checked_project_conflicts
    checked_proj_check_boxes =
      params[:project].select { |_, value| value == "1" }.keys
    return [] if checked_proj_check_boxes.none?

    checked_proj_ids =
      checked_proj_check_boxes.map { |str| str.gsub("id_", "") }
    # Get the AR records so that we can call Project methods on them
    Project.where(id: checked_proj_ids).includes(:location).select do |proj|
      violates_project_constraints?(proj)
    end
  end

  def violates_project_constraints?(project)
    violates_project_location?(project) ||
      violates_project_dates?(project)
  end

  def violates_project_location?(project)
    return false if project.location.blank?

    !project.location.found_here?(@observation)
  end

  def violates_project_dates?(project)
    excluded_from_project_dates?(project)
  end

  def excluded_from_project_dates?(project)
    !included_in_project_dates?(project)
  end

  def included_in_project_dates?(project)
    project_starts_no_later_than?(project) &&
      project_ends_no_earlier_than?(project)
  end

  def project_starts_no_later_than?(project)
    !project.start_date&.after?(@observation.when)
  end

  def project_ends_no_earlier_than?(project)
    !project.end_date&.before?(@observation.when)
  end
end
