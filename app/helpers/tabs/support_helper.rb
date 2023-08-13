# frozen_string_literal: true

module Tabs
  module SupportHelper
    def support_donate_links
      links = [support_donors_link]
      return unless in_admin_mode?

      links += support_admin_links
      links
    end

    def support_donors_links
      links = [support_donate_link]
      return unless in_admin_mode?

      links += support_admin_links
      links
    end

    def support_governance_links
      [
        support_donate_link,
        support_donors_link
      ]
    end

    def support_donors_link
      [:donors_tab.t, support_donors_path, { class: __method__.to_s }]
    end

    def support_donate_link
      [:donate_tab.t, support_donate_path, { class: __method__.to_s }]
    end

    def support_admin_links
      [
        admin_new_donation_link,
        admin_review_donations_link
      ]
    end

    def admin_new_donation_link
      [:create_donation_tab.t, new_admin_donations_path,
       { class: __method__.to_s }]
    end

    def admin_review_donations_link
      [:review_donations_tab.t, admin_review_donations_path,
       { class: __method__.to_s }]
    end
  end
end
