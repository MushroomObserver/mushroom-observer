# frozen_string_literal: true

# Sidebar observations nav: create new observation. User-only.
class Tab::Sidebar::Observations::New < Tab::Base
  def title
    :app_create_observation.t
  end

  def path
    new_observation_path
  end

  def html_options
    { id: "nav_new_observation_link" }
  end
end
