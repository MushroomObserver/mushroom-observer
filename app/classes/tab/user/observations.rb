# frozen_string_literal: true

# "Observations by this user" link. Title defaults to "Observations
# by {name}"; callers pass `text:` to override (e.g. "Your
# observations" for the same-user case).
class Tab::User::Observations < Tab::Base
  def initialize(user:, text: nil)
    super()
    @user = user
    @text = text
  end

  def title
    @text || :show_user_observations_by.t(name: @user.text_name)
  end

  def path
    observations_path(by_user: @user.id)
  end

  def model
    @user
  end
end
