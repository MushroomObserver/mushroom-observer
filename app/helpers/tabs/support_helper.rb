# frozen_string_literal: true

module Tabs
  module SupportHelper
    def support_donate_tabs
      links = [support_donors_tab]
      return unless in_admin_mode?

      links += support_admin_tabs
      links
    end

    def support_donors_tabs
      links = [support_donate_tab]
      return unless in_admin_mode?

      links += support_admin_tabs
      links
    end

    def support_governance_tabs
      [
        support_donate_tab,
        support_donors_tab
      ]
    end

    def support_donors_tab
      [:donors_tab.t, support_donors_path, { class: tab_id(__method__.to_s) }]
    end

    def support_donate_tab
      [:donate_tab.t, support_donate_path, { class: tab_id(__method__.to_s) }]
    end

    def support_admin_tabs
      [
        admin_new_donation_tab,
        admin_review_donations_tab
      ]
    end

    def admin_new_donation_tab
      [:create_donation_tab.t, new_admin_donations_path,
       { class: tab_id(__method__.to_s) }]
    end

    def admin_review_donations_tab
      [:review_donations_tab.t, admin_review_donations_path,
       { class: tab_id(__method__.to_s) }]
    end
  end
end
