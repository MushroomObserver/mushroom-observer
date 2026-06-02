# frozen_string_literal: true

require("test_helper")

module Tab::UserNav
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @user = users(:rolf)
    end

    def test_admin_mode_off
      tab = Tab::UserNav::AdminMode.new(in_admin_mode: false)

      assert_equal(:app_turn_admin_on.t, tab.title)
      assert_equal(routes.admin_mode_path(turn_on: true), tab.path)
      assert_equal(:post, tab.html_options[:button])
    end

    def test_admin_mode_on
      tab = Tab::UserNav::AdminMode.new(in_admin_mode: true)

      assert_equal(:app_turn_admin_off.t, tab.title)
      assert_equal(routes.admin_mode_path(turn_off: true), tab.path)
    end

    def test_logout
      tab = Tab::UserNav::Logout.new

      assert_equal(:app_logout.l, tab.title)
      assert_equal(routes.account_logout_path, tab.path)
      assert_equal(:post, tab.html_options[:button])
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @user = users(:rolf)
    end

    def test_logged_in
      tabs = Tab::UserNav::LoggedIn.new(user: @user).to_a

      assert_equal(
        [Tab::User::Observations, Tab::User::CommentsFor,
         Tab::Project::ForUser, Tab::SpeciesList::ForUser,
         Tab::Account::ShowInterests, Tab::Account::EditProfile,
         Tab::Account::EditPreferences],
        tabs.map(&:class)
      )
    end

    def test_log_out_with_user
      tabs = Tab::UserNav::LogOut.new(user: @user).to_a

      assert_equal(
        [Tab::UserNav::AdminMode, Tab::UserNav::Logout],
        tabs.map(&:class)
      )
    end

    def test_log_out_without_user
      tabs = Tab::UserNav::LogOut.new(user: nil).to_a

      assert_equal([Tab::UserNav::AdminMode], tabs.map(&:class))
    end
  end
end
