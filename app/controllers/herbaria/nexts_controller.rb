# frozen_string_literal: true

module Herbaria
  # Controls viewing and modifying herbaria.
  class NextsController < ApplicationController
    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # index (get)                   Herbaria::Nonpersonals#index (get)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # Display the herbarium which is next in the search results
    def show
      redirect_to_next_object(:next, Herbarium, params[:id].to_s)
    end
  end
end
