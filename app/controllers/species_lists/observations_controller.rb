# frozen_string_literal: true

#
#   :add_remove_observations
# Linked from observations :index and species_lists :show
# Form that sends all obs from current query to be added or removed from an spl

module SpeciesLists
  class ObservationsController < ApplicationController
    before_action :login_required

    # :add_remove_observations
    # Form to add or remove the current *query* of observations
    def edit
      pass_query_params
      @id = params[:species_list].to_s
      @query = find_obs_query_or_redirect
    end

    # :post_add_remove_observations
    # PUT endpoint — via params[:commit], either add or remove a
    #                *query* of observations from a species_list
    def update
      pass_query_params
      id = params[:species_list].to_s
      return unless (spl = find_list_or_reload_form!(id))

      query = find_obs_query_or_redirect(spl)
      return unless query

      do_add_remove_observations_by_query(spl, query)
      redirect_to(species_list_path(spl.id))
    end

    private

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

    def find_list_or_reload_form!(id)
      list = lookup_species_list_by_id_or_name(id)
      return list if list

      flash_error(:species_list_add_remove_bad_name.t(name: id.inspect))
      # id is guaranteed by .to_s not to be nil, but may be a blank string
      redirect_to(edit_species_list_observations_path(species_list: id))
      nil
    end

    def lookup_species_list_by_id_or_name(str)
      if /^\d+$/.match?(str)
        SpeciesList.safe_find(str)
      else
        SpeciesList.find_by(title: str)
      end
    end

    def do_add_remove_observations_by_query(spl, query)
      return unless check_permission!(spl)

      if params[:commit] == :ADD.l
        do_add_observations_by_query(spl, query)
      elsif params[:commit] == :REMOVE.l
        do_remove_observations_by_query(spl, query)
      else
        flash_error("Invalid mode: #{params[:commit].inspect}")
      end
    end

    def do_add_observations_by_query(species_list, query)
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

    def do_remove_observations_by_query(species_list, query)
      ids = query.result_ids & species_list.observation_ids
      return if ids.empty?

      species_list.observation_ids -= ids
      flash_notice(:species_list_add_remove_remove_success.t(num: ids.length))
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
