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

    # Performs a merger of this herbarium into that Herbarium

    def new
      this = find_or_goto_index(Herbarium, params[:this]) || return
      that = find_or_goto_index(Herbarium, params[:that]) || return
      result = perform_or_request_merge(this, that) || return

      redirect_to_herbarium_index(result)
    end

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    # ---------- Modify data


    ############################################################################

    # The bulk of this action is in private methods, which are alse used by
    # Herbaria#create and Herbaria#update

    include Herbaria::SharedPrivateMethods # shared private methods
  end
end
