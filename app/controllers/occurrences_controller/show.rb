# frozen_string_literal: true

# Show and Destroy actions for OccurrencesController.
module OccurrencesController::Show
  def show
    return unless find_occurrence!

    render_show_page
  end

  def destroy
    return unless find_occurrence!

    unless @occurrence.can_edit?(@user)
      flash_error(:permission_denied.t)
      redirect_to(occurrence_path(@occurrence))
      return
    end

    obs_id = @occurrence.primary_observation&.id
    destroy_occurrence!
    redirect_after_dissolve(obs_id)
  end

  private

  def find_occurrence!
    @occurrence = Occurrence.safe_find(params[:id])
    return @occurrence if @occurrence

    flash_error(:occurrence_not_found.t)
    redirect_to(observations_path)
    nil
  end

  def destroy_occurrence!
    @occurrence.dissolve!
  end

  def redirect_after_dissolve(obs_id)
    if @occurrence.destroyed?
      flash_notice(:occurrence_destroyed.t)
      path = obs_id ? permanent_observation_path(obs_id) : observations_path
    else
      flash_notice(:occurrence_updated.t)
      path = occurrence_path(@occurrence)
    end
    redirect_to(path)
  end

  def ordered_observations
    default = @occurrence.primary_observation
    return @occurrence.observations.order(:created_at).to_a unless default

    others = @occurrence.observations.
             where.not(id: default.id).
             order(:created_at).
             includes(:name, :user, :location, :thumb_image)
    [default] + others.to_a
  end

  def render_show_page
    render(
      Views::Controllers::Occurrences::Show.new(
        occurrence: @occurrence,
        observations: ordered_observations,
        user: @user
      ),
      layout: true
    )
  end
end
