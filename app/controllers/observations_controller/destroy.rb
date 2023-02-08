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

    obs_id = @observation.id
    next_state = nil
    # decide where to redirect after deleting observation
    if (this_state = find_query(:Observation))
      this_state.current = @observation
      next_state = this_state.next
    end

    if !check_permission!(@observation)
      flash_error(:runtime_destroy_observation_denied.t(id: obs_id))
      redirect_to(add_query_param({ action: :show, id: obs_id },
                                  this_state))
    elsif !@observation.destroy
      flash_error(:runtime_destroy_observation_failed.t(id: obs_id))
      redirect_to(add_query_param({ action: :show, id: obs_id },
                                  this_state))
    else
      flash_notice(:runtime_destroy_observation_success.t(id: param_id))
      if next_state
        redirect_to(add_query_param({ action: :show,
                                      id: next_state.current_id },
                                    next_state))
      else
        redirect_to(action: :index)
      end
    end
  end
end
