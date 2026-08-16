# frozen_string_literal: true

module Account
  class LoginController < ApplicationController
    before_action :login_required, except: [:new, :create]

    # the login form
    def new
      if @user
        redirect_to(observations_path)
      else
        @login = ""
        @remember = true
        render_new_view
      end
    end

    # login post action
    def create
      render_new_view_invalid and return unless params[:user]

      normalize_login_params
      user = User.authenticate(login: @login, password: @password)

      unless user
        flash_error(:runtime_login_failed.t)
        render_new_view_invalid and return
      end

      user.verified ? login_success(user) : login_unverified(user)
    end

    # This is used to test the autologin feature.
    def test_autologin
      render(Views::Controllers::Account::Login::TestAutologin.new)
    end

    ############################################################################

    private

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::Login::New.new(
               login: @login, remember: @remember
             ), status: status, **render_opts)
    end

    def normalize_login_params
      @login = params.dig(:user, :login).to_s.strip
      @password = params.dig(:user, :password).to_s.strip
      @remember = params.dig(:user, :remember_me) == "1"
    end

    def login_success(user)
      flash_notice(:runtime_login_success.t)
      @user = user
      @user.last_login = now = Time.zone.now
      @user.updated_at = now
      @user.save
      session_user_set(@user)
      @remember ? autologin_cookie_set(@user) : clear_autologin_cookie
      redirect_back_or_default(observations_path)
    end

    def login_unverified(user)
      @unverified_user = user
      render(Views::Controllers::Account::Verifications::Reverify.new(
               unverified_user: @unverified_user
             ), status: :unprocessable_content)
    end
  end
end
