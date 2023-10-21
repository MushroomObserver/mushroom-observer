# frozen_string_literal: true

module Tabs
  module AdminHelper
    def admin_donations_form_edit_tabs
      links = support_governance_tabs
      links << admin_create_donation_tab
      links
    end

    def admin_donations_form_new_tabs
      links = support_governance_tabs
      links << admin_review_donations_tab
      links
    end

    def admin_create_donation_tab
      [:create_donation_tab.t, new_admin_donations_path,
       { class: tab_id(__method__.to_s) }]
    end

    def admin_review_donations_tab
      [:review_donations_tab.t, edit_admin_donations_path,
       { class: tab_id(__method__.to_s) }]
    end

    def admin_test_tabs
      [
        ["Action One", "/"],
        ["Action Two", "/"],
        ["Action Three", "/"]
      ]
    end
  end
end
