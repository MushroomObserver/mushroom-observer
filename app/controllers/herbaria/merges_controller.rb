# frozen_string_literal: true

module Herbaria
  # Combine two herbaria
  class MergesController < ApplicationController
    # filters
    before_action :login_required
    before_action :pass_query_params
    before_action :keep_track_of_referrer

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # merge_herbaria (get)          Herbaria::MergeController#new (get)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    # Merges :this into :that Herbarium if user has sufficient privileges
    # Otherwise sends an email to the webmaster requesting a merger
    def new
      this = find_or_goto_index(Herbarium, params[:this]) || return
      that = find_or_goto_index(Herbarium, params[:that]) || return

      # Calls shared private methods, also used by
      # Herbaria#create and Herbaria#update
      result = perform_or_request_merge(this, that) || return

      # redirect_to_herbarium_index(result)
      redirect_with_query(herbaria_path(id: result.try(&:id)))
    end

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    ############################################################################

    include Herbaria::SharedPrivateMethods # shared private methods
  end
end
