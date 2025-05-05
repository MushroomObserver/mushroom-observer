# frozen_string_literal: true

#  :section: Validators
#  These validators return Boolean values, and also set the @any_errors ivar.
#
#    validate_name
#      name_params
#      resolve_name(...)
#
#    validate_place_name
#
#    validate_projects
#      checked_project_conflicts

# Included in both ObservationsController and NamingsController
module ObservationsController::Validators
  private

  def validate_name
    success = resolve_name
    if @name
      @naming.name = @name
    elsif !success
      @naming.errors.add(:name,
                         :form_observations_there_is_a_problem_with_name.t)
      flash_object_errors(@naming)
    end
    return true if success

    @any_errors = true
    false
  end

  # Set the ivars for the form: @given_name, @name - and potentially ivars for
  # form_name_feedback in the case the name is not resolved unambiguously:
  # @names, @valid_names, @parent_deprecated, @suggest_corrections.
  # Returns true if the name is resolved unambiguously.
  def resolve_name
    resolver = Naming::NameResolver.new(@user, **name_params)
    success = false
    resolver.results.each do |ivar, value|
      if ivar == :success
        success = value
      else
        instance_variable_set(:"@#{ivar}", value)
      end
    end
    success
  end

  # given_name, given_id from observation/naming/fields. Note: nil.to_i == 0
  # approved_name, chosen_name from form_name_feedback
  # also used in namings_controller
  def name_params
    {
      given_name: params.dig(:naming, :name).to_s,
      # given_id: params.dig(:naming, :name_id).to_i,
      approved_name: params[:approved_name].to_s,
      chosen_name: params.dig(:chosen_name, :name_id).to_s
    }
  end

  # The form may be in a state where it has an existing MO Location name in the
  # `place_name` field, but not the corresponding MO location_id. It could be
  # because of user trying to create a duplicate, or because the user had a
  # prefilled location, but clicked on the "Create Location" button - this keeps
  # the place_name, but clears the location_id field. Either way, we need to
  # check if we already have a location by this name. If so, find the existing
  # location and use that for the obs.
  def validate_place_name
    place_name = @observation.place_name
    lat = @observation.lat
    lng = @observation.lng
    if !lat && !lng && place_name.blank?
      @any_errors = true
      return false
    end

    # Set location to unknown if place_name blank && lat/lng are present
    if Location.is_unknown?(place_name) || (lat && lng && place_name.blank?)
      @observation.location = Location.unknown
      @observation.where = nil
      # If it's unknown, we're good. don't need to check for duplicates.
      return true
    end

    name = Location.user_format(@user, @observation.place_name)
    @dubious_where_reasons = Location.dubious_name?(name, true)
    return true if @dubious_where_reasons.empty?

    @any_errors = true
    false
  end

  def validate_projects
    return true if params[:project].empty?

    conflicting_projects = checked_project_conflicts - @observation.projects
    @error_checked_projects = conflicting_projects.reject do |proj|
      proj.is_admin?(User.current)
    end
    if @error_checked_projects.any?
      flash_error(:form_observations_there_is_a_problem_with_projects.t)
      @any_errors = true
      return false
    end

    return true if params[:project][:ignore_proj_conflicts] == "1"

    @suspect_checked_projects = conflicting_projects - @error_checked_projects
    if @suspect_checked_projects.any?
      flash_warning(:form_observations_there_is_a_problem_with_projects.t)
    end
    return true if @suspect_checked_projects.empty?

    @any_errors = true
    false
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

  def validate_observation
    return true if validate_object(@observation)

    @any_errors = true
    false
  end

  def validate_naming
    return true if !@name || validate_object(@naming)

    @any_errors = true
    false
  end

  def validate_vote
    return true if !@name || @vote.value.nil? || validate_object(@vote)

    @any_errors = true
    false
  end

  def validate_images
    return true if @bad_images.empty?

    @any_errors = true
    false
  end
end
