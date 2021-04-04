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
    # merge_herbaria (get)          Herbaria::MergesController#create (post)

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    # Merge :src into :dest Herbarium if user has sufficient privileges
    # Otherwise sends an email to the webmaster requesting a merger
    def create
      src = find_or_goto_index(Herbarium, params[:src]) || return
      dest = find_or_goto_index(Herbarium, params[:dest]) || return

      # Calls shared private methods that are also used by
      # Herbaria#create and Herbaria#update
      result = perform_or_request_merge(src, dest) || return

      # redirect_to_herbarium_index(result)
      redirect_with_query(herbaria_path(id: result.try(&:id)))
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods # shared private methods
  end
end
