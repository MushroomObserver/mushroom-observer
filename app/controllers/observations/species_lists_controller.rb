# frozen_string_literal: true

#   :manage_species_lists
# Linked from observation_tabs_helper, maybe should also link from spl :show?
# Table of links for dealing with a list of obs line by line, can add or remove
#
module Observations
  # Add or remove one Observation from the Observation List
  class SpeciesListsController < ApplicationController
    before_action :login_required

    ###########################################################################
    # :manage_species_lists
    #
    # Form (table of post_button links) to let user add/remove one observation
    # at a time from a species_list. Maybe use param[:commit] like above?
    def edit
      return unless (@observation = find_observation!)

      set_list_ivars
    end

    # new endpoint for :add_observation_to_species_list and
    # :remove_observation_from_species_list. use params[:commit]
    def update
      return unless (@species_list = find_species_list!) &&
                    (@observation = find_observation!)

      unless check_permission!(@species_list)
        return redirect_to(species_list_path(@species_list.id))
      end

      set_list_ivars

      case params[:commit]
      when "add"
        add_observation_to_species_list(@species_list, @observation)
      when "remove"
        remove_observation_from_species_list(@species_list, @observation)
      else
        flash_error("Invalid mode: #{params[:commit].inspect}")
        render("edit",
               location: edit_observation_species_lists_path(
                 id: @observation.id
               ))
      end
    end

    private

    def set_list_ivars
      order_by = params[:by] || :date
      all_lists = Query.lookup(:SpeciesList, editable_by_user: @user, order_by:)

      @obs_lists = []
      @other_lists = []
      all_lists.results.each do |list|
        if list.observations.member?(@observation)
          @obs_lists << list
        else
          @other_lists << list
        end
      end
    end

    def find_observation!
      find_or_goto_index(Observation, params[:id])
    end

    def find_species_list!
      find_or_goto_index(SpeciesList, params[:species_list_id])
    end

    # Used by manage_species_lists.
    def add_observation_to_species_list(species_list, observation)
      species_list.add_observation(observation)
      flash_notice(:runtime_species_list_add_observation_success.
        t(name: species_list.unique_format_name, id: observation.id))
      redirect_to(species_list_path(id: species_list.id))
    end

    # Used by manage_species_lists.
    def remove_observation_from_species_list(species_list, observation)
      species_list.remove_observation(observation)
      flash_notice(:runtime_species_list_remove_observation_success.
        t(name: species_list.unique_format_name, id: observation.id))
      redirect_to(species_list_path(id: species_list.id))
    end
  end
end
