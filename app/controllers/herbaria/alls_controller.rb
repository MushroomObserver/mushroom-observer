# frozen_string_literal: true

module Herbaria
  # Controls viewing and modifying herbaria.
  class AllsController < ApplicationController
    # filters
    before_action: :store_location

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # list_herbaria (get)           Herbaria::All#index (get)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # Display all Herbaria
    # linked (conditionally) from HerbariaIndex
    def index
      query = create_query(:Herbarium, :all, by: :name)
      show_selected_herbaria(query, always_index: true)
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
