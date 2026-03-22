# frozen_string_literal: true

# Show and Destroy actions for OccurrencesController.
module OccurrencesController::Show
  def show
    return unless find_occurrence!

    render_show_page
  end

  def destroy
    return unless find_occurrence!

    unless @occurrence.user == @user
      flash_error(:permission_denied.t)
      redirect_to(occurrence_path(@occurrence))
      return
    end

    primary_obs = @occurrence.primary_observation
    obs_id = primary_obs&.id
    destroy_occurrence!
    flash_notice(:occurrence_destroyed.t)
    path = obs_id ? permanent_observation_path(obs_id) : observations_path
    redirect_to(path)
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
    detached_obs = []
    Occurrence.transaction do
      @occurrence.reset_cross_observation_thumbnails
      @occurrence.observations.each do |obs|
        obs.update!(occurrence: nil)
        detached_obs << obs
      end
      @occurrence.reload.destroy!
    end
    detached_obs.each do |obs|
      Occurrence.log_observation_removed(obs)
      Observation::NamingConsensus.new(obs).calc_consensus
    end
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
