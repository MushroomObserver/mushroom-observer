# frozen_string_literal: true

class VoteController < ApplicationController
  before_action :login_required # except: [:show_votes]

  # Show breakdown of votes for a given naming.
  # Linked from: observations/show
  # Inputs: params[:id] (naming)
  # Outputs: @naming
  def show_votes
    pass_query_params
    @naming = find_or_goto_index(Naming, params[:id].to_s)
  end

  # Create vote if none exists; change vote if exists; delete vote if setting
  # value to -1 (owner of naming is not allowed to do this).
  # Linked from: (nowhere)
  # Inputs: params[]
  # Redirects to show_observation.
  def cast_vote
    pass_query_params
    naming = Naming.find(params[:id].to_s)
    observation = naming.observation
    observation.change_vote(naming, params[:value])
    redirect_with_query(controller: :observations,
                        action: :show,
                        id: observation.id)
  end

  # This is the new POST method for show_observation.
  def cast_votes
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
    redirect_with_query(controller: :observations,
                        action: :show,
                        id: observation.id)
  end

  # This is very expensive, and not called anywhere. Putting it in storage
  # Refresh vote cache for all observations in the database.
  # def refresh_vote_cache
  #   return unless in_admin_mode?

  #   # Naming.refresh_vote_cache
  #   Observation.refresh_vote_cache
  #   flash_notice(:refresh_vote_cache.t)
  #   redirect_with_query(controller: :rss_logs,
  #                       action: :index,
  #                       id: observation.id)
  # end
end
