# frozen_string_literal: true

require("test_helper")

module Tab::Support
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_donors
      tab = Tab::Support::Donors.new

      assert_equal(:donors_tab.t, tab.title)
      assert_equal(routes.support_donors_path, tab.path)
    end

    def test_donate
      tab = Tab::Support::Donate.new

      assert_equal(:donate_tab.t, tab.title)
      assert_equal(routes.support_donate_path, tab.path)
    end

    def test_new_donation
      tab = Tab::Support::NewDonation.new

      assert_equal(:create_donation_tab.t, tab.title)
      assert_equal(routes.new_admin_donations_path, tab.path)
    end

    def test_review_donations
      tab = Tab::Support::ReviewDonations.new

      assert_equal(:review_donations_tab.t, tab.title)
      assert_equal(routes.admin_review_donations_path, tab.path)
    end
  end

  class CollectionsTest < UnitTestCase
    def test_donate_actions_non_admin
      tabs = Tab::Support::DonateActions.new.to_a

      assert_equal([Tab::Support::Donors], tabs.map(&:class))
    end

    def test_donate_actions_admin
      tabs = Tab::Support::DonateActions.new(admin: true).to_a

      assert_equal(
        [Tab::Support::Donors, Tab::Support::NewDonation,
         Tab::Support::ReviewDonations],
        tabs.map(&:class)
      )
    end

    def test_donors_actions_non_admin
      tabs = Tab::Support::DonorsActions.new.to_a

      assert_equal([Tab::Support::Donate], tabs.map(&:class))
    end

    def test_donors_actions_admin
      tabs = Tab::Support::DonorsActions.new(admin: true).to_a

      assert_equal(
        [Tab::Support::Donate, Tab::Support::NewDonation,
         Tab::Support::ReviewDonations],
        tabs.map(&:class)
      )
    end

    def test_governance_actions
      tabs = Tab::Support::GovernanceActions.new.to_a

      assert_equal(
        [Tab::Support::Donate, Tab::Support::Donors],
        tabs.map(&:class)
      )
    end
  end
end
