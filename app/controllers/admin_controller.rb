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

  # Update banner across all translations.
  def change_banner
    if !in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to("/")
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      update_banner_languages
      redirect_to("/")
    else
      @val = :app_banner_box.l.to_s
    end
  end

  ##############################################################################
  #
  #  :section: Admin utilities
  #
  ##############################################################################

  def turn_admin_on
    session[:admin] = true if @user&.admin && !in_admin_mode?
    redirect_back_or_default("/")
  end

  def turn_admin_off
    session[:admin] = nil
    redirect_back_or_default("/")
  end

  def switch_users
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

  def add_user_to_group
    in_admin_mode? ? add_user_to_group_admin_mode : add_user_to_group_user_mode
  end

  # This is messy, but the new User#erase_user method makes a pretty good
  # stab at the problem.
  def destroy_user
    if in_admin_mode?
      id = params["id"]
      if id.present?
        user = User.safe_find(id)
        User.erase_user(id) if user
      end
    end
    redirect_back_or_default("/")
  end

  def blocked_ips
    if in_admin_mode?
      process_blocked_ips_commands
      @blocked_ips = sort_by_ip(IpStats.read_blocked_ips)
      @okay_ips = sort_by_ip(IpStats.read_okay_ips)
      @stats = IpStats.read_stats(do_activity: true)
    else
      redirect_back_or_default("/info/how_to_help")
    end
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

  def update_banner_languages
    time = Time.zone.now
    Language.all.each do |lang|
      if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
        update_banner_string(str, time)
      else
        str = create_banner_string(lang, time)
      end
      str.update_localization
      str.language.update_localization_file
      str.language.update_export_file
    end
  end

  def update_banner_string(str, time)
    str.update!(
      text: @val,
      updated_at: (str.language.official ? time : time - 1.minute)
    )
  end

  def create_banner_string(lang, time)
    lang.translation_strings.create!(
      tag: "app_banner_box",
      text: @val,
      updated_at: time - 1.minute
    )
  end

  # ========= private Admin utilities section methods ==========

  def sort_by_ip(ips)
    ips.sort_by do |ip|
      ip.to_s.split(".").map { |n| n.to_i + 1000 }.map(&:to_s).join(" ")
    end
  end

  # rubocop:disable Metrics/AbcSize
  # I think this is as good as it gets: just a simple switch statement of
  # one-line commands.  Breaking this up doesn't make sense to me.
  # -JPH 2020-10-09
  def process_blocked_ips_commands
    if validate_ip!(params[:add_okay])
      IpStats.add_okay_ips([params[:add_okay]])
    elsif validate_ip!(params[:add_bad])
      IpStats.add_blocked_ips([params[:add_bad]])
    elsif validate_ip!(params[:remove_okay])
      IpStats.remove_okay_ips([params[:remove_okay]])
    elsif validate_ip!(params[:remove_bad])
      IpStats.remove_blocked_ips([params[:remove_bad]])
    elsif params[:clear_okay].present?
      IpStats.clear_okay_ips
    elsif params[:clear_bad].present?
      IpStats.clear_blocked_ips
    elsif validate_ip!(params[:report])
      @ip = params[:report]
    end
  end
  # rubocop:enable Metrics/AbcSize

  def validate_ip!(ip)
    return false if ip.blank?

    match = ip.to_s.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
    return true if match &&
                   valid_ip_num(match[1]) &&
                   valid_ip_num(match[2]) &&
                   valid_ip_num(match[3]) &&
                   valid_ip_num(match[4])

    flash_error("Invalid IP address: \"#{ip}\"")
  end

  def valid_ip_num(num)
    num.to_i >= 0 && num.to_i < 256
  end

  def add_user_to_group_admin_mode
    return unless request.method == "POST"

    user_name  = params["user_name"].to_s
    group_name = params["group_name"].to_s
    user       = User.find_by(login: user_name)
    group      = UserGroup.find_by(name: group_name)

    if can_add_user_to_group?(user, group)
      do_add_user_to_group(user, group)
    else
      do_not_add_user_to_group(user, group, user_name, group_name)
    end

    redirect_back_or_default("/")
  end

  def can_add_user_to_group?(user, group)
    user && group && !user.user_groups.member?(group)
  end

  def do_add_user_to_group(user, group)
    user.user_groups << group
    flash_notice(:add_user_to_group_success. \
      t(user: user.name, group: group.name))
  end

  def do_not_add_user_to_group(user, group, user_name, group_name)
    if user && group
      flash_warning(:add_user_to_group_already. \
        t(user: user_name, group: group_name))
    else
      flash_error(:add_user_to_group_no_user.t(user: user_name)) unless user
      flash_error(:add_user_to_group_no_group.t(group: group_name)) unless group
    end
  end

  def add_user_to_group_user_mode
    flash_error(:permission_denied.t)
    redirect_back_or_default("/")
  end
end
