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

  def render_edit_page
    render(
      Views::Controllers::Occurrences::Edit.new(
        occurrence: @occurrence,
        observations: ordered_observations,
        user: @user
      ),
      layout: true
    )
  end
end
