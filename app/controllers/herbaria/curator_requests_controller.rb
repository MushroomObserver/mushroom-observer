# frozen_string_literal: true

# request to be a herbarium curators
class Herbaria::CuratorRequestsController < ApplicationController
  # filters
  before_action :login_required
  before_action :store_location
  before_action :pass_query_params
  before_action :keep_track_of_referrer

  # Old MO Action (method)        New "Normalized" Action (method)
  # ----------------------        --------------------------------
  # request_to_be_curator (get)   CuratorRequest#new
  # request_to_be_curator (post)  CuratorRequest#create

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  # linked from show page
  def new
    @herbarium = find_or_goto_index(Herbarium, params[:id])
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  # linked from show page
  def create
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium

    subject = "Herbarium Curator Request"
    content =
      "User: ##{@user.id}, #{@user.login}, #{@user.show_url}\n" \
      "Herbarium: #{@herbarium.name}, #{@herbarium.show_url}\n" \
      "Notes: #{params[:notes]}"
    WebmasterEmail.build(@user.email, content, subject).deliver_now
    flash_notice(:show_herbarium_request_sent.t)
    redirect_to_referrer || redirect_to_show_herbarium
  end

  ##############################################################################

  private

  def keep_track_of_referrer
    @back = params[:back] || request.referer
  end

  def redirect_to_referrer
    return false if @back.blank?

    redirect_to(@back)
    true
  end

  def redirect_to_show_herbarium(herbarium = @herbarium)
    redirect_with_query(herbarium.show_link_args)
  end

  def curator_request_params
  end
end
