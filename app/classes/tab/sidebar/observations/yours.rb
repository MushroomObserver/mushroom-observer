# frozen_string_literal: true

# Sidebar observations nav: your observations filter. User-only.
class Tab::Sidebar::Observations::Yours < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :app_your_observations.t
  end

  def path
    observations_path(by_user: @user.id)
  end

  def html_options
    { id: "nav_your_observations_link" }
  end
end
