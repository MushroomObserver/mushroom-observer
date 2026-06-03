# frozen_string_literal: true

# Sidebar observations nav: latest observations (root path).
class Tab::Sidebar::Observations::Latest < Tab::Base
  def title
    :app_latest.t
  end

  def path
    root_path
  end

  def html_options
    { id: "nav_observations_link" }
  end
end
