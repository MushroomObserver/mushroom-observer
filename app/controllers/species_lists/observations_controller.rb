# frozen_string_literal: true

module SpeciesLists
  class ObservationsController < ApplicationController
    before_action :login_required

    def add_remove_observations
      pass_query_params
      @id = params[:species_list].to_s
      @query = find_obs_query_or_redirect
    end

    def post_add_remove_observations
      pass_query_params
      id = params[:species_list].to_s
      spl = find_list_or_reload_form(id)
      return unless spl

      query = find_obs_query_or_redirect(spl)
      return unless query

      do_add_remove_observations(spl, query)
      redirect_to(species_list_path(spl.id))
    end

    def find_obs_query_or_redirect(spl = nil)
      query = find_query(:Observation)
      return query if query

      flash_error(:species_list_add_remove_no_query.t)
      if spl
        redirect_to(species_list_path(spl.id))
      else
        redirect_to(species_lists_path)
      end
      nil
    end

    def find_list_or_reload_form(id)
      list = lookup_species_list_by_id_or_name(id)
      return list if list

      flash_error(:species_list_add_remove_bad_name.t(name: id.inspect))
      redirect_to(add_query_param(action: :add_remove_observations,
                                  species_list: id))
      nil
    end

    def lookup_species_list_by_id_or_name(str)
      if /^\d+$/.match?(str)
        SpeciesList.safe_find(str)
      else
        SpeciesList.find_by(title: str)
      end
    end

    def do_add_remove_observations(spl, query)
      return unless check_permission!(spl)

      if params[:commit] == :ADD.l
        do_add_observations(spl, query)
      elsif params[:commit] == :REMOVE.l
        do_remove_observations(spl, query)
      else
        flash_error("Invalid mode: #{params[:commit].inspect}")
      end
    end

    def do_add_observations(species_list, query)
      ids = query.result_ids - species_list.observation_ids
      return if ids.empty?

      # This is apparently extremely inefficient.  Danny says it times out for
      # large species_lists, such as "Neotropical Fungi".
      # species_list.observation_ids += ids
      SpeciesListObservation.insert_all(
        ids.map do |id|
          { observation_id: id, species_list_id: species_list.id }
        end
      )
      flash_notice(:species_list_add_remove_add_success.t(num: ids.length))
    end

    def do_remove_observations(species_list, query)
      ids = query.result_ids & species_list.observation_ids
      return if ids.empty?

      species_list.observation_ids -= ids
      flash_notice(:species_list_add_remove_remove_success.t(num: ids.length))
    end

    # Form to let user add/remove an observation from one of their species lists.
    def manage_species_lists
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      @all_lists = @user.all_editable_species_lists
    end

    # Used by manage_species_lists.
    def remove_observation_from_species_list
      species_list = find_or_goto_index(SpeciesList, params[:species_list])
      return unless species_list

      observation = find_or_goto_index(Observation, params[:observation])
      return unless observation

      if check_permission!(species_list)
        species_list.remove_observation(observation)
        flash_notice(:runtime_species_list_remove_observation_success.
          t(name: species_list.unique_format_name, id: observation.id))
        redirect_to(action: "manage_species_lists", id: observation.id)
      else
        redirect_to(species_list_path(species_list.id))
      end
    end

    # Used by manage_species_lists.
    def add_observation_to_species_list
      species_list = find_or_goto_index(SpeciesList, params[:species_list])
      return unless species_list

      observation = find_or_goto_index(Observation, params[:observation])
      return unless observation

      if check_permission!(species_list)
        species_list.add_observation(observation)
        flash_notice(:runtime_species_list_add_observation_success.
          t(name: species_list.unique_format_name, id: observation.id))
        redirect_to(action: "manage_species_lists", id: observation.id)
      else
        redirect_to(species_list_path(species_list.id))
      end
    end
  end
end
