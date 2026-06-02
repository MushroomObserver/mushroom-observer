# frozen_string_literal: true

require("test_helper")

# Tab::Account::EditPreferences is split out of the rest of the
# account-domain conversion (next batch) because the theme show
# action-nav composes it. Just one PORO test for now.
module Tab::Account
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_edit_preferences
      tab = Tab::Account::EditPreferences.new

      assert_equal(:prefs_link.t, tab.title)
      assert_equal(routes.edit_account_preferences_path, tab.path)
    end
  end
end
