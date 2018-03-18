class VoteController < ApplicationController
  before_action :login_required, except: [:show_votes]

  # Show breakdown of votes for a given naming.
  # Linked from: show_observation
  # Inputs: params[:id] (naming)
  # Outputs: @naming
  # :nologin: :prefetch:
  def show_votes
    pass_query_params
    @naming = find_or_goto_index(Naming, params[:id].to_s)
  end

  # Create vote if none exists; change vote if exists; delete vote if setting
  # value to -1 (owner of naming is not allowed to do this).
  # Linked from: (nowhere)
  # Inputs: params[]
  # Redirects to show_observation.
  # :norobots:
  def cast_vote
    pass_query_params
    naming = Naming.find(params[:id].to_s)
    observation = naming.observation
    value = params[:value].to_i
    observation.change_vote(naming, value)
    redirect_with_query(controller: :observer,
                        action: :show_observation,
                        id: observation.id)
  end

  # This is the new POST method for show_observation.
  def cast_votes # :norobots:
    pass_query_params
    observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless observation
    if params[:vote]
      flashed = false
      observation.namings.each do |naming|
        value = param_lookup([:vote, naming.id.to_s, :value], &:to_i)
        next unless value &&
                    observation.change_vote(naming, value) &&
                    !flashed
        flash_notice(:runtime_show_observation_success.t)
        flashed = true
      end
    end
    redirect_with_query(controller: :observer,
                        action: :show_observation,
                        id: observation.id)
  end

  # Refresh vote cache for all observations in the database.
  # :root: :norobots:
  def refresh_vote_cache
    return unless in_admin_mode?
    # Naming.refresh_vote_cache
    Observation.refresh_vote_cache
    flash_notice(:refresh_vote_cache.t)
    redirect_with_query(controller: :observer,
                        action: :list_rss_logs,
                        id: observation.id)
  end
end
