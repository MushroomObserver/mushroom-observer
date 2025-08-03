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

    private

    def init_member_vars_for_create
      @member_vote = Vote.maximum_vote
      @member_notes_parts = @species_list.form_notes_parts(@user)
      @member_notes = @member_notes_parts.each_with_object({}) do |part, h|
        h[part.to_sym] = ""
      end
      @member_lat = nil
      @member_lng = nil
      @member_alt = nil
      @member_is_collection_location = true
      @member_specimen = false
    end
  end
end
