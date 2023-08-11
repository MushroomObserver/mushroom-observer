# frozen_string_literal: true

module Tabs
  module AccountHelper
    def admin_donations_form_edit_links
      links = support_governance_links
      links << [:create_donation_tab.t, new_admin_donations_path]
      links
    end

    def admin_donations_form_new_links
      links = support_governance_links
      links << [:review_donations_tab.t, edit_admin_donations_path]
      links
    end
  end
end
