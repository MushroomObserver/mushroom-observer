# frozen_string_literal: true

# "Destroy user" admin button-tab. Caller is responsible for the
# `in_admin_mode?` check.
class Tab::User::AdminDestroy < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :destroy_object.t(TYPE: User)
  end

  def path
    admin_user_path(id: @user.id)
  end

  def html_options
    { button: :destroy }
  end

  def model
    @user
  end
end
