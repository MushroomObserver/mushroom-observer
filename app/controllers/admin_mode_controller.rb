# frozen_string_literal: true

# =============== GET page for access to admin mode ================
#
# NOTE: this controller does not require admin access.
#
# So it cannot currently be namespaced under the AdminController.
# Actions in that namespace require you to be in Admin mode already.

class AdminModeController < ApplicationController
  before_action :login_required

  def show
    if params[:turn_on]
      session[:admin] = true if @user&.admin && !in_admin_mode?
    elsif params[:turn_off]
      session[:admin] = nil
    end

    redirect_back_or_default("/")
  end
end
