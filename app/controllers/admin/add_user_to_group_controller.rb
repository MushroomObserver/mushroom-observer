# frozen_string_literal: true

class Admin::AddUserToGroupController < ApplicationController
  before_action :login_required

  def new
    deny_access unless in_admin_mode?
  end

  def create
    deny_access unless in_admin_mode?
    add_user_to_group
  end

  private

  def add_user_to_group
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

  def deny_access
    flash_error(:permission_denied.t)
    redirect_back_or_default("/")
  end
end
