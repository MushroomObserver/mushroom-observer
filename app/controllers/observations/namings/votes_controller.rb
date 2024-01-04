# frozen_string_literal: true

module Observations::Namings
  class VotesController < ApplicationController
    before_action :login_required # except: [:show]

    # Index breakdown of votes for a given naming.
    # Linked from: observations/show
    # Displayed on show obs via popup for JS users.
    # Has its own route for non-js.
    # Inputs: params[:id] (naming)
    # Outputs: @naming
    def index
      pass_query_params
      @naming = find_or_goto_index(Naming, params[:naming_id].to_s)
      respond_to do |format|
        format.turbo_stream do
          Textile.register_name(@naming.name)
          identifier = "naming_votes_#{@naming.id}"
          title = "#{:show_namings_consensus.t} "
          subtitle = @naming.display_name_brief_authors.t.small_author
          render(partial: "shared/modal",
                 locals: {
                   identifier: identifier, title: title, subtitle: subtitle,
                   body: "observations/namings/votes/table", naming: @naming
                 })
        end
        format.html
      end
    end

    # NOTE: TURBO VOTES NOW HIT THIS CONTROLLER, not the AjaxController.
    # Changes in the state of the Vote selects handled by naming-vote_controller
    # and send a js request to this action, which changes naming votes directly.

    # This action is linked from the show_obs naming table.
    # Each naming row in Show Observation has a form: a select for Votes, and
    # if JS is off, a submit button below the select to save the vote (here).
    #
    # Create vote if none exists; change vote if exists; delete vote if setting
    # value to -1 (owner of naming is not allowed to do this).

    # Linked from: (show_observation and help_identify)
    # Inputs: params[]
    # HTML requests: Redirects to show_observation.
    # Turbo requests: depends on params[:context]
    # when namings_table (show_observation)
    #   Updates namings_table (+ maybe obs title) via update_observation.js.erb
    #   and stimulus naming-vote_controller, which handles <select> bindings
    # when matrix_box (help_identify)
    #   updates the lightbox and matrix_box

    # Split this into create and update, because the caller should know
    # if this user has cast a vote on this naming already or not. Adjust tests.
    def create
      create_or_update_vote
    end

    def update
      create_or_update_vote
    end

    def create_or_update_vote
      pass_query_params
      observation = load_observation_naming_includes # 1st load
      @naming = observation.namings.find(params[:naming_id])
      value_str = param_lookup([:vote, :value])
      value = Vote.validate_value(value_str)
      raise("Bad value.") unless value

      # N+1: Take the whole vote object and send it to change vote?
      # Or how about returning obs.reload from observation.change_vote
      @consensus = ::Observation::NamingConsensus.new(observation)
      @consensus.change_vote(@naming, value, @user) # 2nd load (namings.reload)
      @observation = load_observation_naming_includes # 3rd load
      respond_to_new_votes
    end

    def load_observation_naming_includes
      Observation.naming_includes.find(params[:observation_id])
    end

    def respond_to_new_votes
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "matrix_box"
            render(partial: "observations/namings/update_matrix_box",
                   locals: { obs: @observation })
          else
            obs = Observation.naming_includes.find(@observation.id)
            owner_name = @consensus.owner_preference

            render(partial: "observations/namings/update_observation",
                   locals: { obs: obs, consensus: @consensus,
                             owner_name: owner_name })
          end
          return
        end
        format.html do
          redirect_with_query(observation_path(id: @observation.id))
        end
      end
    end
  end
end
