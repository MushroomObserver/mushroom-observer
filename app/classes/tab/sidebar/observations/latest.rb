# frozen_string_literal: true

# Sidebar observations nav: latest observations. `root_path` server-
# redirects a logged-in user here, but its href doesn't match the
# post-redirect URL for nav-active_controller.js's active-state check
# -- link straight to observations_path instead.
class Tab::Sidebar::Observations::Latest < Tab::Base
  def title
    :app_latest.t
  end

  def path
    observations_path
  end
end
