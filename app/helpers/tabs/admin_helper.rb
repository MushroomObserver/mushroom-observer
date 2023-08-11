# frozen_string_literal: true

module Tabs
  module AdminHelper
    def admin_donations_form_edit_links
      links = support_governance_links
      links << [:create_donation_tab.t, new_admin_donations_path,
                { class: "admin_create_donation_link" }]
      links
    end

    def admin_donations_form_new_links
      links = support_governance_links
      links << [:review_donations_tab.t, edit_admin_donations_path,
                { class: "admin_review_donations_link" }]
      links
    end
  end
end
