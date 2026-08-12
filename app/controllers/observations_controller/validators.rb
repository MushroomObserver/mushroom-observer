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
#      conflicting_among(...)

# Included in both ObservationsController and NamingsController
module ObservationsController::Validators
  private

  def validate_name
    success = resolve_name
    if @name
      @naming.name = @name
    elsif !success
      @naming.errors.add(:name,
                         :form_observations_there_is_a_problem_with_name)
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
      given_name: naming_params_dig(:name).to_s,
      # given_id: naming_params_dig(:name_id).to_i,
      approved_name: params[:approved_name].to_s,
      chosen_name: params.dig(:chosen_name, :name_id).to_s
    }
  end

  # Dig into naming params, checking both old and new param structures
  # Old: params[:naming][:key], New: params[:observation][:naming][:key]
  def naming_params_dig(*keys)
    params.dig(:observation, :naming, *keys) || params.dig(:naming, *keys)
  end

  # Helper methods for nested form params (Superform nests under
  # :observation). `.permit` guarantees each key is a scalar (String)
  # or absent -- an automated scanner sending a nested hash for one of
  # these keys (e.g. `?observation[herbarium_record][name][x]=1`)
  # gets filtered out instead of reaching a Literal `String`/`Integer`
  # prop as the wrong Ruby type.
  def collection_number_params
    (params.dig(:observation, :collection_number) ||
     params[:collection_number])&.permit(:name, :number)
  end

  def herbarium_record_params
    (params.dig(:observation, :herbarium_record) ||
     params[:herbarium_record])&.permit(:herbarium_name, :herbarium_id,
                                        :accession_number)
  end

  # Submitted project_ids array (post-Phlex shape:
  # `observation[project_ids][]=<id>`). `compact_blank` strips the
  # form's sentinel hidden input (value=""), leaving the integer-
  # string IDs the user checked.
  def submitted_project_ids
    params.permit(observation: { project_ids: [] }).
      dig(:observation, :project_ids)&.compact_blank
  end

  # The form may be in a state where it has an existing MO Location name in the
  # `place_name` field, but not the corresponding MO location_id. It could be
  # because of user trying to create a duplicate, or because the user had a
  # prefilled location, but clicked on the "Create Location" button - this keeps
  # the place_name, but clears the location_id field. Either way, we need to
  # check if we already have a location by this name. If so, find the existing
  # location and use that for the obs.
  def validate_place_name
    place_name = @observation.place_name(@user)
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

    @dubious_where_reasons = Location.dubious_reasons_for(
      user: @user, place_name: @observation.place_name(@user)
    )
    return true if @dubious_where_reasons.empty?

    @any_errors = true
    false
  end

  # One pass, one message: every project problem -- checked projects
  # violating constraints, the slip's own (possibly unchecked) target
  # project violating them, cross-prefix leftovers -- surfaces in a
  # single re-render, so the user fixes everything at once instead of
  # discovering the next problem after each save.
  def validate_projects
    checked = checked_projects
    slip_project = slip_prefix_project
    return true if checked.empty? && slip_project.nil?
    return false unless checked_projects_addable?(conflicting_among(checked))
    return true if params.dig(:observation, :ignore_proj_conflicts) == "1"

    gather_suspect_projects(checked, slip_project)
    return true if @suspect_checked_projects.empty? &&
                   @cross_prefix_projects.empty?

    flash_warning(:form_observations_there_is_a_problem_with_projects.t)
    @any_errors = true
    false
  end

  def checked_projects
    ids = submitted_project_ids
    return [] if ids.blank?

    Project.where(id: ids).includes(:location).to_a
  end

  def conflicting_among(projects)
    projects.select { |proj| proj.violates_constraints?(@observation) } -
      @observation.projects
  end

  # Only a checked project can hard-block: invariant 1 (#4932) says a
  # non-admin may not add a violating observation, and checking the
  # box is that act.
  def checked_projects_addable?(conflicting)
    @error_checked_projects = conflicting.reject do |proj|
      proj.is_admin?(@user)
    end
    return true if @error_checked_projects.empty?

    flash_error(:form_observations_there_is_a_problem_with_projects.t)
    @any_errors = true
    false
  end

  # Ticking "use as spare slip" opts out of the slip's project
  # entirely, so neither the slip's own target conflict nor a prefix
  # mismatch against it means anything anymore.
  def gather_suspect_projects(checked, slip_project)
    @suspect_checked_projects = conflicting_among(checked)
    @cross_prefix_projects = []
    return if use_spare_slip?

    add_slip_target_conflict(slip_project, checked)
    @cross_prefix_projects = cross_prefix_checked_projects(checked)
  end

  # The slip's own project is a target even when its box isn't checked
  # -- a typed code doesn't check it, which is how a violation used to
  # surface only AFTER the save. Always a suspect, never a hard error:
  # a non-admin's violating slip lands as a spare post-save
  # (apply_field_slip_project) rather than blocking the create.
  def add_slip_target_conflict(slip_project, checked)
    return if slip_project.nil? || checked.include?(slip_project)
    return if @observation.projects.include?(slip_project)
    # A barred code (closed project, non-member) never attaches at
    # all, so its project is not a target -- validate_field_slip
    # handles that case with its own message.
    return unless slip_project.member?(@user) ||
                  slip_project.can_join?(@user)
    return unless slip_project.violates_constraints?(@observation)

    @slip_target_project = slip_project
    @suspect_checked_projects |= [slip_project]
  end

  # The project the typed/scanned code's prefix names.
  def slip_prefix_project
    prefix = FieldSlip.prefix_for_code(field_code)
    prefix && Project.find_by(field_slip_prefix: prefix)
  end

  # A field slip prefix marks a project as one event's own. When the
  # observation's slip code carries a DIFFERENT prefix, a checked
  # prefix-bearing project is usually the form's remembered leftover
  # from the last event, not intent. A soft constraint: it warns
  # everyone and blocks no one -- the ignore-warnings resubmit
  # proceeds -- because the deliberate case is real (a fair's
  # observations also collected into the herbarium project behind it).
  def cross_prefix_checked_projects(checked)
    prefix = FieldSlip.prefix_for_code(field_code)
    return [] unless prefix

    checked.select do |proj|
      proj.field_slip_prefix.present? && proj.field_slip_prefix != prefix
    end - @observation.projects
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
