# frozen_string_literal: true

module Herbaria
  # Controls viewing and modifying herbaria.
  class FilteredsController < ApplicationController
    # filters

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # index_herbarium (get)         Herbaria::Filtereds#index (get)

    # ---------- Actions to Display data (index, show, etc.) ---------------------

    # Display selected Herbaria based on current Query
    def index
      query = find_or_create_query(:Herbarium, by: params[:by])
      show_selected_herbaria(query, id: params[:id].to_s, always_index: true)
    end

    ##############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
