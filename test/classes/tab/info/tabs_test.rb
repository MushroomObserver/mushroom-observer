# frozen_string_literal: true

require("test_helper")

module Tab::Info
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_site_stats
      tab = Tab::Info::SiteStats.new

      assert_equal(:app_site_stats.t, tab.title)
      assert_equal(routes.info_site_stats_path, tab.path)
    end

    def test_site_stats_actions
      tabs = Tab::Info::SiteStatsActions.new.to_a

      assert_equal(
        [Tab::Contributor::Index, Tab::Checklist::SiteList],
        tabs.map(&:class)
      )
    end
  end
end
