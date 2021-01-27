# frozen_string_literal: true

module Herbaria
  # List Herbaria based on a "pattern" search (defined by the url search string)
  class SearchesController < ApplicationController
    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # herbarium_search (get)        Herbaria::Searches#index (get)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # list of Herbaria whose text matches a string pattern.
    def index
      pattern = params[:pattern].to_s
      if pattern.match(/^\d+$/) && (herbarium = Herbarium.safe_find(pattern))
        redirect_to(herbarium_path(herbarium.id))
      else
        query = create_query(:Herbarium, :pattern_search, pattern: pattern)
        show_selected_herbaria(query)
      end
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
