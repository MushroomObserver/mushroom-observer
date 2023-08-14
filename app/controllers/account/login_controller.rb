# frozen_string_literal: true

module Account
  class LoginController < ApplicationController
    before_action :login_required, except: [
      :new,
      :create,
      :logout,
      :email_new_password,
      :new_password_request
    ]
    before_action :disable_link_prefetching, except: [
      :new,
      :create
    ]

    # the login form
    def new
      @login = ""
      @remember = true
    end

    # login post action
    def create
      render(:new) and return unless params[:user]

      normalize_login_params
      user = User.authenticate(login: @login, password: @password)

      unless user
        flash_error(:runtime_login_failed.t)
        render(:new) and return
      end

      user.verified ? login_success(user) : login_unverified(user)
    end

    def logout
      # Safeguard: reset admin's session to their real_user_id
      if session[:real_user_id].present? &&
         (new_user = User.safe_find(session[:real_user_id])) &&
         new_user.admin
        switch_to_user(new_user)
        redirect_back_or_default("/")
      else
        @user = nil
        User.current = nil
        session_user_set(nil)
        session[:admin] = false
        clear_autologin_cookie
      end
    end

    def email_new_password
      @new_user = User.new
    end

    def new_password_request
      @login = params[:new_user] && params[:new_user][:login]
      @new_user = User.where("login = ? OR name = ? OR email = ?",
                             @login, @login, @login).first
      if @new_user.nil?
        flash_error(:runtime_email_new_password_failed.t(user: @login))
        render("account/login/email_new_password") and return
      else
        set_random_password_for_new_user_and_email_them
      end
    end

    # This is used to test the autologin feature.
    def test_autologin; end

    ############################################################################

    private

    def normalize_login_params
      @login = param_lookup([:user, :login]).to_s.strip
      @password = param_lookup([:user, :password]).to_s.strip
      @remember = param_lookup([:user, :remember_me]) == "1"
    end

    def login_success(user)
      flash_notice(:runtime_login_success.t)
      @user = user
      @user.last_login = now = Time.zone.now
      @user.updated_at = now
      @user.save
      User.current = @user
      session_user_set(@user)
      @remember ? autologin_cookie_set(@user) : clear_autologin_cookie
      redirect_back_or_default("/account/welcome")
    end

    def login_unverified(user)
      @unverified_user = user
      render("/account/verifications/reverify")
    end

    def set_random_password_for_new_user_and_email_them
      password = String.random(10)
      @new_user.change_password(password)
      if @new_user.save
        flash_notice(:runtime_email_new_password_success.tp +
                     :email_spam_notice.tp)
        QueuedEmail::Password.create_email(@new_user, password)
        render("account/login/new")
      else
        flash_object_errors(@new_user)
      end
    end

    def switch_to_user(new_user)
      if session[:real_user_id].blank?
        session[:real_user_id] = User.current_id
        session[:admin] = nil
      elsif session[:real_user_id] == new_user.id
        session[:real_user_id] = nil
        session[:admin] = true
      end
      User.current = new_user
      session_user_set(new_user)
    end
  end
end
