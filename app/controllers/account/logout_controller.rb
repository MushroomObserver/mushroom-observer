# frozen_string_literal: true

module Account
  class LogoutController < ApplicationController
    # GET /account/logout — "you've been logged out" landing page.
    def show
      render(Views::Controllers::Account::Logout::Show.new)
    end

    # POST /account/logout — clear session and redirect to show.
    def create
      real_user = sudo_real_user
      if real_user
        switch_to_user(real_user)
        redirect_back_or_to("/")
      else
        clear_session_and_logout
      end
    end

    private

    def clear_session_and_logout
      @user = nil
      session_user_set(nil)
      clear_autologin_cookie
      redirect_to(account_logout_path)
    end
  end
end
