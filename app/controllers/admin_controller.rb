# frozen_string_literal: true

class AdminController < ApplicationController
  # This changes the params of :login_required to restrict access to admins.
  # To work, admin namespaced controllers must inherit from AdminController
  def authorize?(_user)
    in_admin_mode?
  end

  def access_denied
    flash_error(:permission_denied.t)
    if session[:user_id]
      redirect_to("/")
    else
      redirect_to(new_account_login_path)
    end
  end

  before_action :login_required
end
