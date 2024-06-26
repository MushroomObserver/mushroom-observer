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

# Included in both ObservationsController and NamingsController
module ObservationsController::Validators
  private

  def validate_params
    validate_name &&
      validate_place_name &&
      validate_projects
  end

  def validate_name
    success = resolve_name(**name_args)
    if @name
      @naming.name = @name
    elsif !success
      @naming.errors.add(:name,
                         :form_observations_there_is_a_problem_with_name.t)
      flash_object_errors(@naming)
    end
    success
  end

  # given_name, given_id from observation/naming/fields. Note: nil.to_i == 0
  # approved_name, chosen_name from form_name_feedback
  # also used in namings_controller
  def name_args
    {
      given_name: params.dig(:naming, :name).to_s,
      # given_id: params.dig(:naming, :name_id).to_i,
      approved_name: params[:approved_name].to_s,
      chosen_name: params.dig(:chosen_name, :name_id).to_s
    }
  end

  # Set the ivars for the form: @given_name, @name - and potentially ivars for
  # form_name_feedback in the case the name is not resolved unambiguously:
  # @names, @valid_names, @parent_deprecated, @suggest_corrections.
  def resolve_name(**)
    resolver = Naming::NameResolver.new(**)
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

  def validate_place_name
    success = true
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location_id.nil?
      db_name = Location.user_format(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      success = false if @dubious_where_reasons != []
    end
    success
  end

  def validate_projects
    return true if params[:project].empty? ||
                   params[:project][:ignore_proj_conflicts]

    @suspect_checked_projects = checked_project_conflicts -
                                @observation.projects
    if @suspect_checked_projects.any?
      flash_warning(:form_observations_there_is_a_problem_with_projects.t)
    end
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
