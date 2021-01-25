# frozen_string_literal: true

# Combine two herbaria
class Herbaria::MergesController < ApplicationController
  # filters
  before_action :login_required
  before_action :pass_query_params
  before_action :keep_track_of_referrer

  # Old MO Action (method)        New "Normalized" Action (method)
  # ----------------------        --------------------------------
  # merge_herbaria (get)          Herbaria::MergeController#new (get)

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  # List all herbaria
  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    this = find_or_goto_index(Herbarium, params[:this]) || return
    that = find_or_goto_index(Herbarium, params[:that]) || return
    result = perform_or_request_merge(this, that) || return
    redirect_to_herbarium_index(result)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  # ---------- Modify data

  # ---------- Other

  ##############################################################################

  include Herbaria::SharedPrivateMethods # shared private methods
end
