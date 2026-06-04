# frozen_string_literal: true

# Sidebar info nav: how-to-help page.
class Tab::Sidebar::Info::HowToHelp < Tab::Base
  def title
    :app_how_to_help.t
  end

  def path
    info_how_to_help_path
  end

  def html_options
    { id: "nav_how_to_help_link" }
  end
end
