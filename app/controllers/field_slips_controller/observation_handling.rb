# frozen_string_literal: true

# Private helpers for creating, updating, and linking observations
# when working with field slips.
module FieldSlipsController::ObservationHandling
  private

  def quick_create_observation
    fs_params = params[:field_slip]
    # Must have valid name and location
    location = Location.place_name_to_location(place_name)
    flash_error(:field_slip_quick_no_location.t) unless location
    name = Name.find_by(text_name: fs_params[:field_slip_name])
    notes = field_slip_notes.compact_blank!
    date = extract_date
    obs = Observation.build_observation(location, name, notes, date, @user)
    if obs
      assign_project(obs)
      obs.update!(field_slip: @field_slip)
      @field_slip.adopt_user_from(obs)
      auto_create_occurrence(@field_slip, obs)
      check_for_species_list(obs, params[:species_list])
      name_flash_for_project(name, @field_slip.project)
      redirect_to(observation_url(obs.id))
    else
      redirect_to(new_observation_url(field_code: @field_slip.code,
                                      place_name:, date:, notes:))
    end
  end

  def assign_project(obs)
    project = Project.safe_find(params[:field_slip][:project_id])
    project ||= @filed_slip&.project
    return if project.nil? || project.violates_constraints?(obs)

    project.add_observation(obs)
    @field_slip.update!(project:)
  end

  def update_observation_fields
    obs = @field_slip.observation
    return unless obs

    # Don't update Collector
    notes = field_slip_notes
    notes.delete(:Collector) unless @user == obs.user

    check_name
    # Don't override obs.when or obs.place_name
    obs.notes.value_merge!(notes)
    obs.notes.compact_blank!
    obs.save!
  end

  def check_name
    id_str = params[:field_slip][:field_slip_name]
    return unless id_str

    id_str = strip_textile_formatting(id_str)
    names = Name.find_names(@user, id_str)
    return if names.blank?

    create_naming_and_vote(names[0])
  end

  # Strip textile formatting: "_name Xxx_" -> "Xxx", "_Xxx_" -> "Xxx"
  def strip_textile_formatting(id_str)
    if id_str.start_with?("_name ") && id_str.end_with?("_")
      id_str[6..-2]
    elsif id_str.start_with?("_") && id_str.end_with?("_")
      id_str[1..-2]
    else
      id_str
    end
  end

  def create_naming_and_vote(name)
    naming = @field_slip.observation.namings.find_by(name:)
    unless naming
      naming = Naming.user_construct({}, @field_slip.observation, @user)
      naming.name = name
      naming.save!
    end
    return if Vote.find_by(user: @user, naming:)

    Vote.create!(favorite: true, value: Vote.maximum_vote,
                 naming:, user: @user)
    Observation::NamingConsensus.new(@field_slip.observation).
      user_calc_consensus(@user)
  end

  def disconnect_observation(obs)
    return if params[:commit] == :field_slip_keep_obs.t

    proj = @field_slip.project
    return unless proj && obs && obs.field_slip&.project != proj

    flash_warning(:field_slip_remove_observation.t(
                    observation: obs.user_unique_format_name(@user),
                    title: proj.title
                  ))
    proj.remove_observation(obs)
  end

  def check_last_obs
    return true unless params[:commit] == :field_slip_last_obs.t

    obs = ObservationView.previous(@user, @field_slip.observation)
    return false unless obs # This should not ever happen
    return false unless last_obs_project_ok?(obs)

    Observation.transaction do
      old_obs = @field_slip.observation
      old_obs&.update!(field_slip: nil) if old_obs != obs
      obs.update!(field_slip: @field_slip)
      @field_slip.adopt_user_from(obs)
      auto_create_occurrence(@field_slip, obs)
    end
    true
  end

  def last_obs_project_ok?(obs)
    return true unless (project = @field_slip.project)
    return false unless project.user_can_add_observation?(obs, @user)

    if project.violates_constraints?(obs)
      flash_error(:field_slip_constraint_violation.t)
      return false
    end
    project.add_observation(obs)
    true
  end

  def auto_create_occurrence(field_slip, obs)
    Occurrence.find_or_create_for_field_slip(field_slip, obs, @user)
  end
end
