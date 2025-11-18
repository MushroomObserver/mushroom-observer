# frozen_string_literal: true

module Tabs
  module Sidebar
    module AdminHelper
      def sidebar_admin_tabs
        [
          admin_jobs_tab,
          admin_blocked_ips_tab,
          admin_switch_users_tab,
          admin_users_tab,
          admin_banners_tab,
          admin_email_all_users_tab,
          admin_licenses_tab
        ]
      end

      def admin_jobs_tab
        InternalLink.new(
          :app_jobs.t, "/jobs",
          html_options: { id: "nav_admin_jobs_link" }
        ).tab
      end

      def admin_blocked_ips_tab
        InternalLink.new(
          :app_blocked_ips.t, edit_admin_blocked_ips_path,
          html_options: { id: "nav_admin_blocked_ips_link" }
        ).tab
      end

      def admin_switch_users_tab
        InternalLink.new(
          :app_switch_users.t, edit_admin_mode_path,
          html_options: { id: "nav_admin_switch_users_link" }
        ).tab
      end

      def admin_users_tab
        InternalLink.new(
          :app_users.t, users_path(by: "name"),
          html_options: { id: "nav_admin_user_index_link" }
        ).tab
      end

      def admin_banners_tab
        InternalLink.new(
          :change_banner_title.t, admin_banners_path,
          html_options: { id: "nav_admin_edit_banner_link" }
        ).tab
      end

      def admin_email_all_users_tab
        InternalLink.new(
          :app_email_all_users.t, new_admin_emails_features_path,
          html_options: { id: "nav_admin_emails_features_link" }
        ).tab
      end

      def admin_licenses_tab
        InternalLink.new(
          :LICENSES.t, licenses_path,
          html_options: { id: "nav_admin_licenses_link" }
        ).tab
      end
    end
  end
end
