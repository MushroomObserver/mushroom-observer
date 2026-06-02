# frozen_string_literal: true

module Tabs
  module AdminHelper
    def admin_donations_form_edit_tabs
      links = ::Tab::Support::GovernanceActions.new.map(&:to_a)
      links << admin_create_donation_tab
      links
    end

    def admin_donations_form_new_tabs
      links = ::Tab::Support::GovernanceActions.new.map(&:to_a)
      links << ::Tab::Support::ReviewDonations.new.to_a
      links
    end

    def admin_create_donation_tab
      InternalLink::Model.new(
        :create_donation_tab.t, Donation, new_admin_donations_path
      ).tab
    end

    # Overridden by SupportHelper#admin_review_donations_tab
    # def admin_review_donations_tab
    #   InternalLink::Model.new(
    #     :review_donations_tab.t, Donation, edit_admin_donations_path
    #   ).tab
    # end

    def admin_test_tabs
      [
        ["Action One", "/"],
        ["Action Two", "/"],
        ["Action Three", "/"]
      ]
    end
  end
end
