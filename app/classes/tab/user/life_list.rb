# frozen_string_literal: true

# "User's life list" checklist link.
class Tab::User::LifeList < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_life_list.t
  end

  def path
    checklist_path(id: @user.id)
  end

  def model
    @user
  end
end
