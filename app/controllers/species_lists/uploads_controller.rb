# frozen_string_literal: true

module SpeciesLists
  class UploadsController < ApplicationController
    before_action :login_required

    # Form to let user add to a species_list from file.
    def new
      return unless (@species_list = find_species_list!)

      if check_permission!(@species_list)
        query = create_query(:Observation, :in_species_list,
                             by: :name, species_list: @species_list)
        @observation_list = query.results
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    # Upload form posts here
    def create
      return unless (@species_list = find_species_list!)

      if check_permission!(@species_list)
        sorter = NameSorter.new
        @species_list.file = params[:species_list][:file]
        @species_list.process_file_data(sorter)
        init_name_vars_from_sorter(@species_list, sorter)
        init_member_vars_for_edit(@species_list)
        init_project_vars_for_edit(@species_list)
        @checklist ||= calc_checklist
        render("species_lists/edit")
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
