# frozen_string_literal: true

# Sidebar info nav: donate page link.
class Tab::Sidebar::Info::Donate < Tab::Base
  def title
    :app_donate.t
  end

  def path
    support_donate_path
  end

  def html_options
    { id: "nav_donate_link" }
  end
end
