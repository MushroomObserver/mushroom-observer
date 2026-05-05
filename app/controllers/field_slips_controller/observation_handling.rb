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
      link_obs_to_field_slip(obs)
      @field_slip.adopt_user_from(obs)
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
    project ||= @field_slip&.project
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

  # Link an observation to a field slip via an occurrence.
  def link_obs_to_field_slip(obs)
    occ = @field_slip.occurrence
    if occ
      obs.update!(occurrence: occ) unless obs.occurrence_id == occ.id
    else
      occ = Occurrence.create!(
        user: @user, primary_observation: obs,
        field_slip: @field_slip
      )
      obs.update!(occurrence: occ)
    end
  end

  def check_last_obs
    return true unless params[:commit] == :field_slip_last_obs.t

    obs = ObservationView.previous(@user, @field_slip.observation)
    return false unless obs # This should not ever happen
    return false unless last_obs_project_ok?(obs)

    Observation.transaction do
      link_obs_to_field_slip(obs)
      @field_slip.reload
      @field_slip.occurrence&.update!(primary_observation: obs)
      @field_slip.adopt_user_from(obs)
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

  # -- Occurrence linking for field slips --

  def attach_selected_observations
    obs_ids = Array(params[:observation_ids]).map(&:to_i)
    return if obs_ids.empty?

    selected = Observation.where(id: obs_ids).
               includes({ occurrence: :field_slip }).to_a
    ensure_occurrence_for_field_slip(selected)
  end

  def sync_selected_observations
    return unless params.key?(:observation_ids)

    selected_ids = Array(params[:observation_ids]).to_set(&:to_i)
    occ = @field_slip.occurrence
    return create_new_field_slip_occurrence(selected_ids) unless occ

    sync_occurrence_observations(occ, selected_ids)
  end

  def create_new_field_slip_occurrence(selected_ids)
    return if selected_ids.empty?

    selected = Observation.where(id: selected_ids).to_a
    ensure_occurrence_for_field_slip(selected)
  end

  def sync_occurrence_observations(occ, selected_ids)
    current_ids = occ.observation_ids.to_set
    detach_field_slip_observations(occ, current_ids - selected_ids)
    attach_field_slip_observations(occ, selected_ids - current_ids)
    occ.reload
    update_occurrence_primary(occ)
    occ.recompute_has_specimen!
    occ.recalculate_consensus! unless occ.destroyed?
    check_field_slip_project_gaps(occ) unless occ.destroyed?
  end

  def detach_field_slip_observations(occ, remove_ids)
    remove_ids.each do |obs_id|
      obs = Observation.find_by(id: obs_id)
      next unless obs

      occ.reassign_thumbnails_from(obs)
      obs.update!(occurrence: nil)
      Occurrence.log_field_slip_removed(obs, occ)
      Observation::NamingConsensus.new(obs).calc_consensus
    end
  end

  def attach_field_slip_observations(occ, add_ids)
    added = []
    add_ids.each do |obs_id|
      obs = Observation.find_by(id: obs_id)
      next unless obs

      obs.update!(occurrence: occ)
      added << obs
    end
    Occurrence.log_field_slip_added(added) if added.any?
  end

  def update_occurrence_primary(occ)
    primary = resolve_primary(occ.observations.to_a)
    occ.update!(primary_observation: primary)
  end

  def resolve_primary(obs_list)
    primary_id = params.dig(:field_slip,
                            :primary_observation_id).to_i
    obs_list.find { |o| o.id == primary_id } || obs_list.first
  end

  def ensure_occurrence_for_field_slip(selected)
    primary = resolve_primary(selected)
    occ = @field_slip.occurrence
    if occ
      newly_added = add_to_existing_field_slip_occ(occ, selected)
      occ.update!(primary_observation: primary)
    else
      occ = Occurrence.create!(user: @user,
                               primary_observation: primary,
                               field_slip: @field_slip)
      selected.each { |obs| obs.update!(occurrence: occ) }
      newly_added = selected
    end
    Occurrence.log_field_slip_added(newly_added) if newly_added&.any?
    occ.recompute_has_specimen!
    occ.recalculate_consensus!
    check_field_slip_project_gaps(occ)
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.message)
  end

  def add_to_existing_field_slip_occ(occ, selected)
    added = []
    selected.each do |obs|
      next if obs.occurrence_id == occ.id

      obs.update!(occurrence: occ)
      added << obs
    end
    added
  end

  def check_field_slip_project_gaps(occ)
    return unless occ&.persisted?

    gaps = occ.project_membership_gaps
    return unless gaps.any?

    @field_slip_project_gaps = gaps
    @field_slip_occurrence = occ
  end
end
