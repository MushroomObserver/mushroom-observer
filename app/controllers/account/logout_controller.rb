# frozen_string_literal: true

module Account
  class LogoutController < ApplicationController
    # GET /account/logout — "you've been logged out" landing page.
    def show
      render(Views::Controllers::Account::Logout::Show.new)
    end

    # POST /account/logout — clear session and redirect to show.
    def create
      real_user = User.safe_find(session[:real_user_id]) if
        session[:real_user_id].present?
      if real_user&.admin
        switch_to_user(real_user)
        redirect_back_or_to("/")
      else
        clear_session_and_logout
      end
    end

    private

    def clear_session_and_logout
      @user = nil
      User.current = nil
      session_user_set(nil)
      session[:admin] = false
      session[:real_user_id] = nil
      clear_autologin_cookie
      redirect_to(account_logout_path)
    end
  end
end
