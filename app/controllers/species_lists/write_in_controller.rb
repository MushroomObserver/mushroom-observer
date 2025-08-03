# frozen_string_literal: true

module SpeciesLists
  class WriteInController < ApplicationController
    before_action :login_required

    def new
      @species_list = SpeciesList.find(params[:id])
      init_member_vars_for_create
    end

    def create
      @species_list = SpeciesList.find(params[:id])
      if check_permission!(@species_list)
        process_species_list(:create)
      else
        redirect_to(species_list_path(@species_list))
      end
    end

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
