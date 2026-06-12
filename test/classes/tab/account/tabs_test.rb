# frozen_string_literal: true

require("test_helper")

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

    def test_edit_profile
      tab = Tab::Account::EditProfile.new

      assert_equal(:profile_link.t, tab.title)
      assert_equal(routes.edit_account_profile_path, tab.path)
    end

    def test_bulk_license_updater
      tab = Tab::Account::BulkLicenseUpdater.new

      assert_equal(:bulk_license_link.t, tab.title)
      assert_equal(routes.images_edit_licenses_path, tab.path)
    end

    def test_show_notifications
      tab = Tab::Account::ShowNotifications.new

      assert_equal(:show_user_your_notifications.t, tab.title)
      assert_equal(routes.interests_path, tab.path)
    end

    def test_show_interests
      tab = Tab::Account::ShowInterests.new

      assert_equal(:app_your_interests.t, tab.title)
      assert_equal(routes.interests_path, tab.path)
    end

    def test_show_api_keys
      tab = Tab::Account::ShowAPIKeys.new

      assert_equal(:account_api_keys_link.t, tab.title)
      assert_equal(routes.account_api_keys_path, tab.path)
    end

    def test_change_image_vote_anonymity
      tab = Tab::Account::ChangeImageVoteAnonymity.new

      assert_equal(:prefs_change_image_vote_anonymity.t, tab.title)
      assert_equal(routes.images_edit_vote_anonymity_path, tab.path)
    end
  end

  class CollectionsTest < UnitTestCase
    def test_profile_edit_actions
      tabs = Tab::Account::ProfileEditActions.new.to_a

      assert_equal(
        [Tab::Account::BulkLicenseUpdater,
         Tab::Account::ShowNotifications,
         Tab::Account::EditPreferences,
         Tab::Account::ShowAPIKeys],
        tabs.map(&:class)
      )
    end

    def test_preferences_edit_actions
      tabs = Tab::Account::PreferencesEditActions.new.to_a

      assert_equal(
        [Tab::Account::BulkLicenseUpdater,
         Tab::Account::ChangeImageVoteAnonymity,
         Tab::Account::EditProfile,
         Tab::Account::ShowNotifications,
         Tab::Account::ShowAPIKeys],
        tabs.map(&:class)
      )
    end

    def test_api_actions
      tabs = Tab::Account::APIActions.new.to_a

      assert_equal(
        [Tab::Account::EditPreferences, Tab::Account::EditProfile],
        tabs.map(&:class)
      )
    end
  end
end
