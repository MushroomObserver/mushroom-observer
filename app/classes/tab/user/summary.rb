# frozen_string_literal: true

# "Your summary" — same path as Profile but labeled for the
# same-user (self-view) sidebar / nav context.
class Tab::User::Summary < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_your_summary.l
  end

  def path
    user_path(@user.id)
  end

  def model
    @user
  end
end
