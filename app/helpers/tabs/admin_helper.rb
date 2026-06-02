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
  end
end
