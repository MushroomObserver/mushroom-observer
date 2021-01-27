# frozen_string_literal: true

module Herbaria
# Controls viewing and modifying herbaria.
  class CuratorsController < ApplicationController
    # filters
    before_action :login_required
    before_action :pass_query_params, only: [
      :destroy
    ]
    before_action :keep_track_of_referrer, only: [
      :destroy
    ]

    # Old MO Action (method)        New "Normalized" Action (method)
    # ----------------------        --------------------------------
    # delete_curator (delete)       Curators#destroy
    # show_herbarium (post)         add_curator(get)? => Curators#create

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    # There is no "new" action; the forms are inlined by Herbaria#show

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    def create
      @herbarium = find_or_goto_index(Herbarium, params[:id])
      if @user && (@herbarium.curator?(@user) || in_admin_mode?)
        login = params[:add_curator].to_s.sub(/ <.*/, "")
        user = User.find_by(login: login)
        if user
          @herbarium.add_curator(user)
        else
          flash_error(:show_herbarium_no_user.t(login: login))
        end
      end
      redirect_to_show_herbarium
    end

    def destroy
      @herbarium = find_or_goto_index(Herbarium, params[:id])
      return unless @herbarium

      user = User.safe_find(params[:user])
      if !@herbarium.curator?(@user) && !in_admin_mode?
        flash_error(:permission_denied.t)
      elsif user && @herbarium.curator?(user)
        @herbarium.delete_curator(user)
      end
      redirect_to_referrer || redirect_to_show_herbarium
    end

    ############################################################################

    include Herbaria::SharedPrivateMethods
  end
end
