# frozen_string_literal: true

# Edit and Update actions for OccurrencesController.
module OccurrencesController::Edit
  def edit
    return unless find_occurrence!

    render_edit_page
  end

  def update
    return unless find_occurrence!

    process_update
  end

  private

  def process_update
    primary_obs = @occurrence.primary_observation
    sync_observations if params.key?(:observation_ids)
    if params[:create_observation]
      handle_create_observation
    else
      update_primary
      update_primary_obs_attributes
    end
    recalculate_occurrence_consensus
    redirect_after_update(primary_obs)
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.message)
    redirect_to(edit_occurrence_path(@occurrence))
  end

  def redirect_after_update(primary_obs)
    if @occurrence.destroyed?
      flash_notice(:occurrence_destroyed.t)
      redirect_to_observation_or_index(primary_obs)
    else
      flash_notice(:occurrence_updated.t)
      @project_gaps = @occurrence.project_membership_gaps
      if @project_gaps.any?
        render_edit_page
      else
        redirect_to(occurrence_path(@occurrence))
      end
    end
  end

  def redirect_to_observation_or_index(obs)
    return redirect_to(observations_path) unless obs

    redirect_to(permanent_observation_path(obs.id))
  end

  def sync_observations
    selected_ids = parse_selected_ids
    current_ids = @occurrence.observation_ids.to_set

    remove_unchecked_observations(current_ids - selected_ids)
    return if @occurrence.destroyed?

    add_checked_observations(selected_ids - current_ids)
    return unless Occurrence.exists?(@occurrence.id)

    @occurrence.reload
    @occurrence.recompute_has_specimen!
  end

  def parse_selected_ids
    Array(params[:observation_ids]).
      map(&:to_i).reject(&:zero?).to_set
  end

  def remove_unchecked_observations(remove_ids)
    remove_ids.each do |obs_id|
      obs = @occurrence.observations.find_by(id: obs_id)
      next unless obs
      next unless can_remove_observation?(obs)

      @occurrence.reassign_thumbnails_from(obs)
      obs.update!(occurrence: nil)
      Occurrence.log_observation_removed(obs, @occurrence)
      recalculate_standalone_consensus(obs)
    end
    @occurrence.reload
    @occurrence.destroy_if_incomplete!
  end

  def add_checked_observations(add_ids)
    return if add_ids.empty?

    new_obs = Observation.where(id: add_ids).
              includes({ occurrence: :field_slip }).to_a
    validate_additions(new_obs)
    new_obs.each { |obs| add_single_observation(obs) }
    @occurrence.reload
    @occurrence.recompute_has_specimen!
  end

  def validate_additions(new_obs)
    all_obs = @occurrence.observations.to_a + new_obs
    Occurrence.check_field_slip_conflicts!(all_obs)
    Occurrence.check_max_observations!(all_obs)
  end

  def add_single_observation(obs)
    if obs.occurrence && obs.occurrence != @occurrence
      Occurrence.merge!(@occurrence, obs.occurrence)
    else
      obs.update!(occurrence: @occurrence)
      Occurrence.log_observation_added([obs])
    end
  end

  def can_remove_observation?(_obs)
    @occurrence.can_edit?(@user)
  end

  def update_primary
    return unless @occurrence.persisted? && !@occurrence.destroyed?

    new_primary_id = params.dig(:occurrence, :primary_observation_id)
    return unless new_primary_id

    new_primary = @occurrence.observations.find_by(
      id: new_primary_id.to_i
    )
    return unless new_primary

    @occurrence.update!(primary_observation: new_primary)
  end

  def update_primary_obs_attributes
    return unless @occurrence.persisted? && !@occurrence.destroyed?

    obs = @occurrence.primary_observation
    return unless obs

    obs_params = params[:primary_obs]
    return unless obs_params

    update_obs_location(obs, obs_params)
    update_obs_date(obs, obs_params)
    return unless obs.changed?

    unless obs.can_edit?(@user)
      flash_error(:edit_occurrence_no_edit_permission.t)
      obs.reload
      return
    end

    obs.save!
  end

  def update_obs_location(obs, obs_params)
    new_loc_id = obs_params[:location_id]&.to_i
    return unless new_loc_id&.positive?
    return if new_loc_id == obs.location_id

    location = Location.find_by(id: new_loc_id)
    return unless location

    obs.location = location
    obs.where = location.name
  end

  def update_obs_date(obs, obs_params)
    new_when = obs_params[:when]
    return if new_when.blank?

    parsed = Date.parse(new_when)
    obs.when = parsed if parsed != obs.when
  rescue Date::Error
    nil
  end

  def handle_create_observation
    return unless @occurrence.persisted? && !@occurrence.destroyed?

    source = find_source_observation
    notes = source.notes.to_h
    new_obs = Observation.build_observation(
      source.location, source.name, notes,
      source.when, @user
    )
    new_obs.where = source.where
    new_obs.save!
    new_obs.update!(occurrence: @occurrence)
    @occurrence.update!(primary_observation: new_obs)
    @occurrence.recompute_has_specimen!
  end

  def find_source_observation
    source_id = params.dig(
      :occurrence, :primary_observation_id
    )&.to_i
    @occurrence.observations.find_by(id: source_id) ||
      @occurrence.primary_observation
  end

  def candidate_observations
    current_ids = @occurrence.observation_ids
    ObservationView.where(user: @user).
      where.not(observation_id: current_ids).
      order(last_view: :desc).
      limit(3).
      includes(observation: [:name, :user, :location,
                             :thumb_image,
                             { occurrence: :field_slip }]).
      filter_map(&:observation)
  end

  def render_edit_page
    render(
      Views::Controllers::Occurrences::Edit.new(
        occurrence: @occurrence,
        observations: ordered_observations,
        candidates: candidate_observations,
        user: @user,
        project_gaps: @project_gaps
      ),
      layout: true
    )
  end

  def recalculate_occurrence_consensus
    return if @occurrence.destroyed?

    @occurrence.recalculate_consensus!
  end

  # Recalculate consensus for an observation removed from an occurrence
  def recalculate_standalone_consensus(obs)
    Observation::NamingConsensus.new(obs).calc_consensus
  end
end
