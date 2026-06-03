# frozen_string_literal: true

# Sidebar info nav: intro page.
class Tab::Sidebar::Info::Intro < Tab::Base
  def title
    :app_intro.t
  end

  def path
    info_intro_path
  end

  def html_options
    { id: "nav_intro_link" }
  end
end
