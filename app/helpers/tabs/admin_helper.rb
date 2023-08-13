# frozen_string_literal: true

module Tabs
  module AdminHelper
    def admin_donations_form_edit_links
      links = support_governance_links
      links << admin_create_donation_link
      links
    end

    def admin_donations_form_new_links
      links = support_governance_links
      links << admin_review_donations_link
      links
    end

    def admin_create_donation_link
      [:create_donation_tab.t, new_admin_donations_path,
       { class: __method__.to_s }]
    end

    def admin_review_donations_link
      [:review_donations_tab.t, edit_admin_donations_path,
       { class: __method__.to_s }]
    end

    def admin_test_links
      [
        ["Action One", "/"],
        ["Action Two", "/"],
        ["Action Three", "/"]
      ]
    end
  end
end
