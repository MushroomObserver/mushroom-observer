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

      # Checked ahead of verification: a correct password on a flagged
      # account is one that may be known to someone else, so it buys no
      # session on any path.
      return login_reset_required(user) if user.password_reset_required

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
      flash_emailed_password_warning(user)
      @user = user
      @user.last_login = now = Time.zone.now
      @user.updated_at = now
      @user.save
      session_user_set(@user)
      @remember ? autologin_cookie_set(@user) : clear_autologin_cookie
      redirect_back_or_default(observations_path)
    end

    # A password mailed as cleartext is a stopgap until the reset
    # moves to a link that lets the person set their password. Until
    # then, say so at the one moment they hold both passwords in
    # mind. The marker is dropped on read, so the nudge shows once.
    def flash_emailed_password_warning(user)
      return unless session.delete(:password_emailed_to) == user.id

      flash_warning(:runtime_login_emailed_password.t)
    end

    def login_unverified(user)
      @unverified_user = user
      render_unverified_view_invalid
    end

    def login_reset_required(user)
      @flagged_user = user
      render_reset_required_view_invalid
    end

    def render_reset_required_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::Login::PasswordResetRequired.new(
               flagged_user: @flagged_user
             ), status: status, **render_opts)
    end

    def render_reset_required_view_invalid(**)
      render_reset_required_view(**)
      self.status = :unprocessable_content
    end

    def render_unverified_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::Verifications::Reverify.new(
               unverified_user: @unverified_user
             ), status: status, **render_opts)
    end

    def render_unverified_view_invalid(**)
      render_unverified_view(**)
      self.status = :unprocessable_content
    end
  end
end
