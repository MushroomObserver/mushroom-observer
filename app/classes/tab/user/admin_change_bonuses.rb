# frozen_string_literal: true

# "Change user bonuses" admin link. Caller is responsible for the
# `in_admin_mode?` check.
class Tab::User::AdminChangeBonuses < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :change_user_bonuses.t
  end

  def path
    edit_admin_user_path(@user.id)
  end

  def model
    @user
  end
end
