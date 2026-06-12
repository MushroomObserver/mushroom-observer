# frozen_string_literal: true

# Action-nav for the site_stats info page.
class Tab::Info::SiteStatsActions < Tab::Collection
  private

  def tabs
    [Tab::Contributor::Index.new,
     Tab::Checklist::SiteList.new]
  end
end
