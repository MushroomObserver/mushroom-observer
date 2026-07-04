# frozen_string_literal: true

# Sidebar info nav: site stats page.
class Tab::Sidebar::Info::SiteStats < Tab::Base
  def title
    :app_site_stats.t
  end

  def path
    info_site_stats_path
  end
end
