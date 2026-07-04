# frozen_string_literal: true

# Sidebar info nav: how-to-use page.
class Tab::Sidebar::Info::HowToUse < Tab::Base
  def title
    :app_how_to_use.t
  end

  def path
    info_how_to_use_path
  end
end
