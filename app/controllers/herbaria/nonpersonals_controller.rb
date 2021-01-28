# frozen_string_literal: true

module Herbaria
  # Controls viewing and modifying herbaria.
  class NonpersonalsController < ApplicationController
    # filters
    before_action(:store_location)

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # index (get)                   Herbaria::Nonpersonals#index (get)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # Display list of nonpersonal herbaria (herbarium.personal_id == nil)
    def index
      query = create_query(:Herbarium, :nonpersonal, by: :code_then_name)
      show_selected_herbaria(query, always_index: true)
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
