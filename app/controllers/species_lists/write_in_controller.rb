# frozen_string_literal: true

module SpeciesLists
  class WriteInController < ApplicationController
    before_action :login_required

    def new
      @species_list = SpeciesList.find(params[:id])
    end

    def create
    end
  end
end
