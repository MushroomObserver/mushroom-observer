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

    default_obs = @occurrence.default_observation
    destroy_occurrence!
    flash_notice(:occurrence_destroyed.t)
    redirect_to(permanent_observation_path(default_obs.id))
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
    Occurrence.transaction do
      @occurrence.observations.each do |obs|
        obs.update!(occurrence: nil)
      end
      @occurrence.reload.destroy!
    end
  end

  def ordered_observations
    default = @occurrence.default_observation
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
