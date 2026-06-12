# frozen_string_literal: true

# Sidebar info nav: contributors index.
class Tab::Sidebar::Info::Contributors < Tab::Base
  def title
    :app_contributors.t
  end

  def path
    contributors_path
  end

  def html_options
    { id: "nav_contributors_link" }
  end
end
