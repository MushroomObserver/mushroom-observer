# frozen_string_literal: true

# "Show user profile" link.
class Tab::User::Profile < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :show_object.t(type: :profile)
  end

  def path
    user_path(@user.id)
  end

  def model
    @user
  end
end
