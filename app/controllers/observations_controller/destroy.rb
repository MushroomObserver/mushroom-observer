# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::Destroy
  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: observations/show (note that links require jquery_ujs)
  # Inputs: params[:id] (observation)
  # Redirects to next obs in query or :index.
  def destroy
    param_id = params[:id].to_s
    return unless (@observation = find_or_goto_index(Observation, param_id))

    @observation.current_user = @user
    obs_id = @observation.id
    # decide where to redirect after deleting observation, using Query.next_id
    if (this_query = find_query(:Observation))
      this_query.current_id = @observation.id
      next_id = this_query.next_id
    end

    if !permission!(@observation)
      flash_error(:runtime_destroy_observation_denied.t(id: obs_id))
      redirect_to({ action: :show, id: obs_id })
    elsif !@observation.destroy
      flash_error(:runtime_destroy_observation_failed.t(id: obs_id))
      redirect_to({ action: :show, id: obs_id })
    else
      flash_notice(:runtime_destroy_observation_success.t(id: param_id))
      redirect_after_destroy(this_query, next_id)
    end
  end

  private

  def redirect_after_destroy(query, next_id)
    if query && next_id
      redirect_to({ action: :show, id: next_id })
    else
      redirect_to(action: :index)
    end
  end
end
