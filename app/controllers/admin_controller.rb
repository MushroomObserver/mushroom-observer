# frozen_string_literal: true

#  ==== Admin utilities
#  test_flash_redirection::      <tt>(R . .)</tt>
#  change_banner::      <tt>(R . .)</tt>
#  turn_admin_on::      <tt>(R . .)</tt>
#  turn_admin_off::     <tt>(R . .)</tt>
#  switch_users::       <tt>(R V .)</tt>
#  add_user_to_group::  <tt>(R V .)</tt>
#  create_alert::       <tt>(R V .)</tt>
#  destroy_user::       <tt>(R . .)</tt>
#  blocked_ips::        <tt>(R V .)</tt>

class AdminController < ApplicationController
  before_action :login_required

  ### Custom login_required behavior for this controller
  def authorize?(_user)
    in_admin_mode?
  end

  def access_denied
    flash_error(:permission_denied.t)
    if session[:user_id]
      redirect_to("/")
    else
      redirect_to(herbaria_path)
    end
  end

  def show
    @redirect_path = herbaria_path
  end

  def test_flash_redirection
    tags = params[:tags].to_s.split(",")
    if tags.any?
      flash_notice(tags.pop.to_sym.t)
      redirect_to(
        controller: :admin,
        action: :test_flash_redirection,
        tags: tags.join(",")
      )
    else
      # (sleight of hand to prevent localization_file_text from complaining
      # about missing test_flash_redirection_title tag)
      # Disable cop in order to use sleight of hand
      @title = "test_flash_redirection_title".to_sym.t # rubocop:disable Lint/SymbolConversion
      render(layout: "application", html: "")
    end
  end
end
