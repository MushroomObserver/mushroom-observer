# frozen_string_literal: true

class Tab::SpeciesList::ForUser < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_your_lists.l
  end

  def path
    species_lists_path(by_user: @user.id)
  end
end
