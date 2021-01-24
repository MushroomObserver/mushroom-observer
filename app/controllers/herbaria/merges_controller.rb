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

  private

  def perform_or_request_merge(this, that)
    if in_admin_mode? || this.can_merge_into?(that)
      perform_merge(this, that)
    else
      request_merge(this, that)
    end
  end

  def perform_merge(this, that)
    old_name = this.name_was
    result = this.merge(that)
    flash_notice(:runtime_merge_success.t(
                 type: :herbarium, this: old_name, that: result.name)
    )
    result
  end

  def request_merge(this, that)
    redirect_with_query(
      observer_email_merge_request_path(
        type: :Herbarium, old_id: this.id, new_id: that.id
      )
    )
    false
  end

  def keep_track_of_referrer
    @back = params[:back] || request.referer
  end

  def redirect_to_referrer
    return false if @back.blank?

    redirect_to(@back)
    true
  end

  def redirect_to_herbarium_index(herbarium = @herbarium)
    redirect_with_query(filtered_herbaria_path(id: herbarium.try(&:id)))
  end

  def merge_params
  end
end
