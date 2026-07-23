# frozen_string_literal: true

module Observations::Namings
  class VotesController < ApplicationController
    before_action :login_required # except: [:show]

    # Index breakdown of votes for a given naming.
    # Linked from: observations/show
    # Displayed on show obs via popup for JS users.
    # Has its own route for non-js access and testing.
    # The HTML response renders the Phlex `Index` view (which
    # derives consensus internally from `naming.observation`); the
    # turbo response renders the Phlex `Table` inside a Modal.
    def index
      @naming = find_or_goto_index(Naming, params[:naming_id].to_s)
      return unless @naming

      respond_to do |format|
        format.turbo_stream { render_votes_modal }
        format.html { render_phlex_index }
      end
    end

    private

    def render_phlex_index
      render(Views::Controllers::Observations::Namings::Votes::Index.new(
               naming: @naming
             ))
    end

    # Picks the MergedNaming display unit when one exists so votes
    # are aggregated across siblings, then defers the modal markup
    # to the `Modal` Phlex wrapper.
    def render_votes_modal
      ::Textile.register_name(@naming.name)
      consensus = ::Observation::NamingConsensus.new(@naming.observation)
      display_naming = consensus.merged_namings.find do |mn|
        mn.name_id == @naming.name_id
      end || @naming
      render(Views::Controllers::Observations::Namings::Votes::Modal.new(
               naming: display_naming, user: @user,
               modal_id: "modal_naming_votes_#{@naming.id}",
               title: "#{:show_namings_consensus.t} "
             ))
    end

    public

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

    private

    def create_or_update_vote
      observation = load_observation_naming_includes # 1st load
      @naming = observation.namings.find(params[:naming_id])
      value_str = params.dig(:vote, :value).to_s
      value = Vote.validate_value(value_str)
      raise("Bad value.") unless value

      @consensus = ::Observation::NamingConsensus.new(observation)
      owner_pref_before = @consensus.owner_preference
      @consensus.change_vote(@naming, value, @user)
      propagate_vote_to_siblings(@naming, value, @consensus)
      @observation = load_observation_naming_includes # reload
      @owner_pref_changed = owner_pref_changed?(owner_pref_before)
      respond_to_new_votes
    end

    # The owner-pref line on the obs-show title is in the page
    # chrome (separate `content_for(:owner_naming)` from the
    # namings panel turbo target). `render_namings_section_update`
    # uses this flag to choose between a panel-only swap and a
    # full-page redirect that re-renders the title chrome.
    def owner_pref_changed?(before)
      ::Observation::NamingConsensus.new(@observation).owner_preference&.id !=
        before&.id
    end

    def propagate_vote_to_siblings(naming, value, consensus)
      return unless naming.observation.occurrence_id

      sibling_namings = consensus.namings.select do |n|
        n.name_id == naming.name_id && n.id != naming.id
      end
      sibling_namings.each do |sib_naming|
        sib_consensus = ::Observation::NamingConsensus.new(
          sib_naming.observation
        )
        sib_consensus.change_vote(sib_naming, value, @user)
      end
    end

    def load_observation_naming_includes
      Observation.naming_includes.find(params[:observation_id])
    end

    def respond_to_new_votes
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "namings_table"
            render_namings_section_update
          when "matrix_box"
            render_matrix_box_naming_update
          end
        end
        format.html do
          redirect_to(@observation.show_link_args)
        end
      end
    end

    # Re-render the whole obs template if either the consensus or
    # the obs owner's preferred name changed — both live in the
    # page chrome (page title + `content_for(:owner_naming)`)
    # which the namings-panel turbo_stream target can't reach.
    # Otherwise, just update the namings panel in place.
    def render_namings_section_update
      if @consensus.consensus_changed || @owner_pref_changed
        redirect_to(@observation.show_link_args) and return
      end

      render_obs_section_update(
        identifier: "namings",
        panel: Views::Controllers::Observations::Show::Namings.new(
          obs: @observation, user: @user, consensus: @consensus
        )
      ) and return
    end

    # Successful-vote-change response when the request came from
    # the lightbox / matrix-box context: swap the obs title in
    # both places, dismiss any open naming / progress modals, and
    # clear the identify strip. Mirrors `NamingsController`'s
    # version — same 7 turbo-stream actions, same shape.
    def render_matrix_box_naming_update
      obs_id = @observation.id
      render(turbo_stream: [
               turbo_stream.replace(
                 "observation_what_#{obs_id}",
                 Components::ObservationFragment.new(
                   type: :lightbox_title,
                   obs: @observation, user: @user, identify: false
                 )
               ),
               turbo_stream.replace(
                 "box_title_#{obs_id}",
                 Components::Matrix::Box::Title.new(
                   id: obs_id,
                   name: @observation.format_name(@user).
                         t.break_name.small_author,
                   type: :observation
                 )
               ),
               turbo_stream.close_modal("modal_obs_#{obs_id}_naming"),
               turbo_stream.remove("modal_obs_#{obs_id}_naming"),
               turbo_stream.close_modal("mo_ajax_progress"),
               turbo_stream.remove("mo_ajax_progress"),
               turbo_stream.remove("observation_identify_#{obs_id}")
             ])
    end
  end
end
