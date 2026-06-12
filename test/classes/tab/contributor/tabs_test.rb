# frozen_string_literal: true

require("test_helper")

module Tab::Contributor
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_index
      tab = Tab::Contributor::Index.new

      assert_equal(:app_contributors.t, tab.title)
      assert_equal(routes.contributors_path, tab.path)
    end

    def test_index_actions
      tabs = Tab::Contributor::IndexActions.new.to_a

      assert_equal([Tab::Info::SiteStats], tabs.map(&:class))
    end
  end
end
