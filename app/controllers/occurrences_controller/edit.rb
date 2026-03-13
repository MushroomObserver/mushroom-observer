# frozen_string_literal: true

# Edit and Update actions for OccurrencesController.
module OccurrencesController::Edit
  def edit
    return unless find_occurrence!
    return unless permitted?

    render_edit_page
  end

  def update
    return unless find_occurrence!
    return unless permitted?

    process_update
  end

  private

  def permitted?
    return true if @occurrence.can_edit?(@user)

    flash_error(:permission_denied.t)
    redirect_to(occurrence_path(@occurrence))
    false
  end

  def process_update
    default_obs = @occurrence.default_observation
    handle_additions
    handle_removals
    update_default
    redirect_after_update(default_obs)
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.message)
    redirect_to(edit_occurrence_path(@occurrence))
  end

  def redirect_after_update(default_obs)
    if @occurrence.destroyed?
      flash_notice(:occurrence_destroyed.t)
      redirect_to(permanent_observation_path(default_obs.id))
    else
      flash_notice(:occurrence_updated.t)
      redirect_to(occurrence_path(@occurrence))
    end
  end

  def handle_additions
    add_ids = Array(params[:add_observation_ids]).map(&:to_i)
    return if add_ids.empty?

    new_obs = load_additions(add_ids)
    return if new_obs.empty?

    validate_additions(new_obs)
    add_observations_to_occurrence(new_obs)
  end

  def load_additions(add_ids)
    Observation.where(id: add_ids).
      includes(:field_slip, :occurrence).to_a
  end

  def validate_additions(new_obs)
    all_obs = @occurrence.observations.includes(:field_slip).to_a +
              new_obs
    Occurrence.check_field_slip_conflicts!(all_obs)
    Occurrence.check_max_observations!(all_obs)
  end

  def add_observations_to_occurrence(new_obs)
    new_obs.each { |obs| add_single_observation(obs) }
    @occurrence.reload
    @occurrence.recompute_has_specimen!
  end

  def add_single_observation(obs)
    if obs.occurrence && obs.occurrence != @occurrence
      Occurrence.merge!(@occurrence, obs.occurrence)
    else
      obs.update!(occurrence: @occurrence)
    end
  end

  def handle_removals
    remove_ids = Array(params[:remove_observation_ids]).map(&:to_i)
    return if remove_ids.empty?

    remove_ids.each do |obs_id|
      obs = @occurrence.observations.find_by(id: obs_id)
      next unless obs

      obs.update!(occurrence: nil)
    end
    @occurrence.reload
    @occurrence.destroy_if_incomplete!
  end

  def update_default
    return unless @occurrence.persisted? && !@occurrence.destroyed?

    new_default_id = params.dig(:occurrence, :default_observation_id)
    return unless new_default_id

    new_default = @occurrence.observations.find_by(
      id: new_default_id.to_i
    )
    return unless new_default

    @occurrence.update!(default_observation: new_default)
  end

  def candidate_observations
    current_ids = @occurrence.observation_ids
    ObservationView.where(user: @user).
      where.not(observation_id: current_ids).
      order(last_view: :desc).
      limit(3).
      includes(observation: [:name, :user, :location,
                             :thumb_image, :field_slip,
                             :occurrence]).
      filter_map(&:observation)
  end

  def render_edit_page
    render(
      Views::Controllers::Occurrences::Edit.new(
        occurrence: @occurrence,
        observations: ordered_observations,
        candidates: candidate_observations,
        user: @user
      ),
      layout: true
    )
  end
end
