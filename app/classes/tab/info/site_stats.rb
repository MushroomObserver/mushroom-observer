# frozen_string_literal: true

# "Site statistics" page link.
class Tab::Info::SiteStats < Tab::Base
  def title
    :app_site_stats.t
  end

  def path
    info_site_stats_path
  end
end
