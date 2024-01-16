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
    (success, @what, @name, @names, @valid_names,
     @parent_deprecated, @suggest_corrections) = resolve_name_ivars(params)
    if @name
      @naming.name = @name
    elsif !success
      @naming.errors.add(:name,
                         :form_observations_there_is_a_problem_with_name.t)
      flash_object_errors(@naming)
    end
    success
  end

  def resolve_name_ivars(params)
    given_name = params.dig(:naming, :name).to_s
    chosen_name = params.dig(:chosen_name, :name_id).to_s
    @resolver = Naming::NameResolver.new(
      given_name, params[:approved_name], chosen_name
    )
    # NOTE: views could be refactored to access properties of the @resolver,
    # e.g. `@resolver.valid_names`, instead of these ivars.
    # All but success, @what, @name are only used by form_name_feedback.
    @resolver.ivar_array
  end

  def validate_place_name(params)
    success = true
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location.nil?
      db_name = Location.user_format(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      success = false if @dubious_where_reasons != []
    end
    success
  end

  def validate_projects(params)
    return true if params[:project].empty? ||
                   params[:project][:ignore_proj_conflicts]

    @suspect_checked_projects = checked_project_conflicts -
                                @observation.projects
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
      proj.violates_constraints?(@observation)
    end
  end
end
