# frozen_string_literal: true

class Admin::SwitchUsersController < ApplicationController
  before_action :login_required

  def new
    unless in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to("/")
    end
  end

  def create
    unless in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to("/")
    end

    @id = params[:id].to_s
    new_user = find_user_by_id_login_or_email(@id)
    flash_error("Couldn't find \"#{@id}\".  Play again?") \
      if new_user.blank? && @id.present?
    if !@user&.admin && session[:real_user_id].blank?
      redirect_back_or_default("/")
    elsif new_user.present?
      switch_to_user(new_user)
      redirect_back_or_default("/")
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

  private

  def find_user_by_id_login_or_email(str)
    if str.blank?
      nil
    elsif str.match?(/^\d+$/)
      User.safe_find(str)
    else
      User.find_by(login: str) || User.find_by(email: str.sub(/ <.*>$/, ""))
    end
  end
end
