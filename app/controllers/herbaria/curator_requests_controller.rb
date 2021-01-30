# frozen_string_literal: true

module Herbaria
  # request to be a herbarium curators
  class Herbaria::CuratorRequestsController < ApplicationController
    # filters
    before_action :login_required
    before_action :store_location
    before_action :pass_query_params
    before_action :keep_track_of_referrer

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------------  --------------------------------
    # request_to_be_curator (get)   Herbaria::CuratorRequest#new (get)
    # request_to_be_curator (post)  Herbaria::CuratorRequest#create (post)

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    # Display form for user to request being added as a curator, and email form
    # to webmaster when form is submitted.
    # Linked from herbarium show page
    def new
      @herbarium = find_or_goto_index(Herbarium, params[:id])
    end

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    # Email the completed form to the webmaster
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
      redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
