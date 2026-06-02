# frozen_string_literal: true

require("test_helper")

module Tab::Admin
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def test_create_donation
      tab = Tab::Admin::CreateDonation.new

      assert_equal(:create_donation_tab.t, tab.title)
      assert_equal(routes.new_admin_donations_path, tab.path)
      assert_equal(Donation, tab.model)
    end
  end

  class CollectionsTest < UnitTestCase
    def test_donations_form_new
      tabs = Tab::Admin::DonationsFormNew.new.to_a

      assert_equal(
        [Tab::Support::Donate, Tab::Support::Donors,
         Tab::Support::ReviewDonations],
        tabs.map(&:class)
      )
    end

    def test_donations_form_edit
      tabs = Tab::Admin::DonationsFormEdit.new.to_a

      assert_equal(
        [Tab::Support::Donate, Tab::Support::Donors,
         Tab::Admin::CreateDonation],
        tabs.map(&:class)
      )
    end
  end
end
