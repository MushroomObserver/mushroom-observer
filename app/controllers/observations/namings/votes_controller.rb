# frozen_string_literal: true

module Observations::Namings
  class VotesController < ApplicationController
    before_action :login_required # except: [:show]

    # Show breakdown of votes for a given naming.
    # Linked from: observations/show
    # Displayed on show obs via popup for JS users.
    # Has its own route for non-js.
    # Inputs: params[:id] (naming)
    # Outputs: @naming
    def show
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
    # JS requests: depends on params[:context]
    # when namings_table (show_observation)
    #   Updates namings_table (+ maybe obs title) via update_observation.js.erb
    #   and stimulus naming-vote_controller, which handles <select> bindings
    # when matrix_box (help_identify)
    #   updates the lightbox and matrix_box

    def update
      pass_query_params
      @naming = Naming.find(params[:naming_id].to_s)
      observation = @naming.observation
      value_str = param_lookup([:vote, :value])
      value = Vote.validate_value(value_str)
      raise("Bad value.") unless value

      observation.change_vote(@naming, value, @user)
      @observation = observation.reload
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "matrix_box"
            render(partial: "observations/namings/update_matrix_box")
          else
            render(partial: "observations/namings/update_observation")
          end
          return
        end
        format.html do
          redirect_with_query(observation_path(id: @observation.id))
        end
      end
    end

    # This is very expensive, and not called anywhere. Putting it in storage
    # Refresh vote cache for all observations in the database.
    # def refresh_vote_cache
    #   return unless in_admin_mode?

    #   # Naming.refresh_vote_cache
    #   Observation.refresh_vote_cache
    #   flash_notice(:refresh_vote_cache.t)
    #   redirect_with_query(rss_logs_path(observation.id))
    # end
  end
end
