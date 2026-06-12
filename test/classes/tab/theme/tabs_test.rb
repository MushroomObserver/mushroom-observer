# frozen_string_literal: true

require("test_helper")

module Tab::Theme
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_list
      tab = Tab::Theme::List.new

      assert_equal(:theme_list.t, tab.title)
      assert_equal(routes.theme_color_themes_path, tab.path)
    end
  end

  class CollectionsTest < UnitTestCase
    def test_show_actions
      tabs = Tab::Theme::ShowActions.new.to_a

      assert_equal(
        [Tab::Theme::List, Tab::Account::EditPreferences],
        tabs.map(&:class)
      )
    end
  end
end
