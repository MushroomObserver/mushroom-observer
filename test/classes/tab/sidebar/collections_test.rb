# frozen_string_literal: true

require("test_helper")

# Smoke tests for each sidebar Collection. Single-tab POROs aren't
# tested individually — each is a one-line `:key.t` + path + id;
# composition tests below pin the wiring.
module Tab::Sidebar
  class CollectionsTest < UnitTestCase
    def setup
      @user = users(:rolf)
    end

    def test_admin_actions
      tabs = Tab::Sidebar::AdminActions.new.to_a

      assert_equal(
        [Tab::Sidebar::Admin::Jobs,
         Tab::Sidebar::Admin::BlockedIps,
         Tab::Sidebar::Admin::SwitchUsers,
         Tab::Sidebar::Admin::Users,
         Tab::Sidebar::Admin::Banners,
         Tab::Sidebar::Admin::Licenses],
        tabs.map(&:class)
      )
    end

    def test_login_actions
      tabs = Tab::Sidebar::LoginActions.new.to_a

      assert_equal(
        [Tab::Sidebar::Login, Tab::Sidebar::Signup],
        tabs.map(&:class)
      )
    end

    def test_indexes_actions
      tabs = Tab::Sidebar::IndexesActions.new.to_a

      assert_equal(
        [Tab::Sidebar::Indexes::Glossary,
         Tab::Sidebar::Indexes::Herbaria,
         Tab::Sidebar::Indexes::Locations,
         Tab::Sidebar::Indexes::Names,
         Tab::Sidebar::Indexes::Projects],
        tabs.map(&:class)
      )
    end

    def test_info_actions
      tabs = Tab::Sidebar::InfoActions.new.to_a

      assert_equal(12, tabs.length)
      assert_instance_of(Tab::Sidebar::Info::MobileApp, tabs.first)
      assert_instance_of(Tab::Sidebar::Info::PrivacyPolicy, tabs.last)
    end

    def test_latest_actions_no_user
      tabs = Tab::Sidebar::LatestActions.new.to_a

      assert_equal([Tab::Sidebar::Latest::News], tabs.map(&:class))
    end

    def test_latest_actions_with_user
      tabs = Tab::Sidebar::LatestActions.new(user: @user).to_a

      assert_equal(
        [Tab::Sidebar::Latest::News,
         Tab::Sidebar::Latest::Changes,
         Tab::Sidebar::Latest::Images,
         Tab::Sidebar::Latest::Comments],
        tabs.map(&:class)
      )
    end

    def test_observations_actions_no_user
      tabs = Tab::Sidebar::ObservationsActions.new.to_a

      assert_equal([Tab::Sidebar::Observations::Latest], tabs.map(&:class))
    end

    def test_observations_actions_with_user
      tabs = Tab::Sidebar::ObservationsActions.new(user: @user).to_a

      assert_equal(
        [Tab::Sidebar::Observations::Latest,
         Tab::Sidebar::Observations::New,
         Tab::Sidebar::Observations::Yours,
         Tab::Sidebar::Observations::Identify],
        tabs.map(&:class)
      )
    end

    def test_species_lists_actions_no_user
      tabs = Tab::Sidebar::SpeciesListsActions.new.to_a

      assert_equal([Tab::Sidebar::SpeciesLists::All], tabs.map(&:class))
    end

    def test_species_lists_actions_with_user
      tabs = Tab::Sidebar::SpeciesListsActions.new(user: @user).to_a

      assert_equal(
        [Tab::Sidebar::SpeciesLists::Yours,
         Tab::Sidebar::SpeciesLists::All,
         Tab::Sidebar::SpeciesLists::New],
        tabs.map(&:class)
      )
    end

    def test_user_actions
      tabs = Tab::Sidebar::UserActions.new(user: @user).to_a

      assert_equal(
        [Tab::User::CommentsFor,
         Tab::Account::ShowInterests,
         Tab::User::Summary,
         Tab::Account::EditPreferences,
         Tab::Sidebar::User::JoinMailingList],
        tabs.map(&:class)
      )
    end

    # Regression: both used to hardcode the literal id
    # "nav_articles_link" — an actual duplicate-id-in-DOM bug for any
    # logged-in user, since Latest and Indexes render on the same
    # page. Their auto-derived classes (from each one's own title)
    # must be distinct.
    def test_news_and_glossary_have_distinct_classes
      news = Tab::Sidebar::Latest::News.new
      glossary = Tab::Sidebar::Indexes::Glossary.new

      assert_not_equal(news.html_options[:class], glossary.html_options[:class])
    end
  end
end
