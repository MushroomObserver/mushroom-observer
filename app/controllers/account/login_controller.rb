# frozen_string_literal: true

class Account::LoginController < ApplicationController
  before_action :login_required, except: [
    :new,
    :create,
    :logout
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
    user_params = params[:user] || {}
    @login = user_params[:login].to_s
    @password = user_params[:password].to_s
    @remember = user_params[:remember_me] == "1"
    user = User.authenticate(login: @login, password: @password)
    user ||= User.authenticate(login: @login, password: @password.strip)

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

  ##############################################################################
  #
  #  :section: Testing
  #
  ##############################################################################

  # This is used to test the autologin feature.
  def test_autologin; end

  private

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
    render("/account/reverify")
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
