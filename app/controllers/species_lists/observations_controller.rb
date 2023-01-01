# frozen_string_literal: true

#   :manage_species_lists
# Linked from observation_tabs_helper, maybe should also link from spl :show?
# Table of links for dealing with a list of obs line by line, can add or remove
#
module SpeciesLists
  class ObservationsController < ApplicationController
    before_action :login_required

    ###########################################################################
    # :manage_species_lists
    #
    # Form (table of post_button links) to let user add/remove one observation
    # at a time from a species list. Maybe use param[:commit] like above?
    def edit
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      @all_lists = @user.all_editable_species_lists
    end

    # new endpoint for :add_observation_to_species_list and
    # :remove_observation_from_species_list. use params[:commit]
    def update
      return unless (species_list = find_species_list!)

      return unless (observation = find_observation!)

      unless check_permission!(species_list)
        return redirect_to(species_list_path(species_list.id))
      end

      if params[:commit] == :ADD.l
        add_observation_to_species_list(species_list, observation)
      elsif params[:commit] == :REMOVE.l
        remove_observation_from_species_list(species_list, observation)
      else
        flash_error("Invalid mode: #{params[:commit].inspect}")
      end
    end

    private

    # Used by manage_species_lists.
    def remove_observation_from_species_list(species_list, observation)
      species_list.remove_observation(observation)
      flash_notice(:runtime_species_list_remove_observation_success.
        t(name: species_list.unique_format_name, id: observation.id))
      redirect_to(action: :edit, id: observation.id)
    end

    # Used by manage_species_lists.
    def add_observation_to_species_list(species_list, observation)
      species_list.add_observation(observation)
      flash_notice(:runtime_species_list_add_observation_success.
        t(name: species_list.unique_format_name, id: observation.id))
      redirect_to(action: :edit, id: observation.id)
    end

    def find_species_list!
      find_or_goto_index(SpeciesList, params[:species_list])
    end

    def find_observation!
      find_or_goto_index(Observation, params[:observation])
    end
  end
end
