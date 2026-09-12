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
    # Permission first, THEN the reflection guard -- so a user who can't
    # delete the observation gets the standard denial without being told
    # it is a reflection (matches EditAndUpdate#editable_or_redirect?).
    return if destroy_denied?(obs_id)
    return if destroy_blocked_for_reflection?(obs_id)

    # decide where to redirect after deleting observation, using Query.next_id
    if (this_query = find_query(:Observation))
      this_query.current_id = @observation.id
      next_id = this_query.next_id
    end

    # Refetch fresh (non-strict_loading) for the destroy cascade. current_user
    # doesn't carry over from @observation above - it's a different instance.
    if refetch_for_destroy(@observation.id).destroy
      flash_notice(:runtime_destroy_observation_success.t(id: param_id))
      redirect_after_destroy(this_query, next_id)
    else
      flash_error(:runtime_destroy_observation_failed.t(id: obs_id))
      redirect_to({ action: :show, id: obs_id })
    end
  end

  private

  # Standard permission-denied path. Checked before the reflection guard,
  # so a non-owner gets the usual denial rather than the reflection
  # warning (which would leak that the observation is a reflection).
  def destroy_denied?(obs_id)
    return false if permission!(@observation)

    flash_error(:runtime_destroy_observation_denied.t(id: obs_id))
    redirect_to(action: :show, id: obs_id)
    true
  end

  # A read-only reflection mirrors its imported source and is changed
  # only by resync; deleting it on MO would drop the mirror (and its
  # import link) while the source lives on. Block it like the edit lock.
  def destroy_blocked_for_reflection?(obs_id)
    return false unless @observation.reflection?

    flash_warning(:destroy_observation_is_reflection.t)
    redirect_to(action: :show, id: obs_id)
    true
  end

  def refetch_for_destroy(id)
    obs = Observation.find(id)
    obs.current_user = @user
    obs
  end

  def redirect_after_destroy(query, next_id)
    if query && next_id
      redirect_to({ action: :show, id: next_id })
    else
      redirect_to(action: :index)
    end
  end
end
