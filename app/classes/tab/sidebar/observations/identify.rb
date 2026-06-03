# frozen_string_literal: true

# Sidebar observations nav: help identify observations. User-only.
class Tab::Sidebar::Observations::Identify < Tab::Base
  def title
    :app_help_id_obs.t
  end

  def path
    identify_observations_path
  end

  def html_options
    { id: "nav_identify_observations_link" }
  end
end
