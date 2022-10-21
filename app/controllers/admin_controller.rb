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
  include Admin::RestrictAccessToAdminMode

  before_action :login_required

  def show; end

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

  ##############################################################################
  #
  #  :section: Admin utilities
  #
  ##############################################################################

  # def turn_admin_on
  #   session[:admin] = true if @user&.admin && !in_admin_mode?
  #   redirect_back_or_default("/")
  # end

  # def turn_admin_off
  #   session[:admin] = nil
  #   redirect_back_or_default("/")
  # end

  # def add_user_to_group
  #   in_admin_mode? ? add_user_to_group_admin_mode : add_user_to_group_user_mode
  # end

  # This is messy, but the new User#erase_user method makes a pretty good
  # stab at the problem.
  def destroy_user
    id = params["id"]
    if id.present?
      user = User.safe_find(id)
      User.erase_user(id) if user
    end
    redirect_back_or_default("/")
  end

  # ========= private Admin utilities section methods ==========
end
