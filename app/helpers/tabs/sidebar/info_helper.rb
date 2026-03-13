# frozen_string_literal: true

module Tabs
  module Sidebar
    module InfoHelper
      def sidebar_info_tabs
        [
          nav_mobile_app_tab,
          nav_intro_tab,
          nav_how_to_use_tab,
          nav_donate_tab,
          nav_how_to_help_tab,
          nav_report_a_bug_tab,
          nav_send_a_comment_tab,
          nav_contributors_tab,
          nav_site_stats_tab,
          nav_translators_note_tab,
          nav_publications_tab,
          nav_privacy_policy_tab
        ]
      end

      def nav_mobile_app_tab
        InternalLink.new(:app_mobile.t, article_path(34),
                         html_options: { id: "nav_mobile_app_link" }).tab
      end

      def nav_intro_tab
        InternalLink.new(:app_intro.t, info_intro_path,
                         html_options: { id: "nav_intro_link" }).tab
      end

      def nav_how_to_use_tab
        InternalLink.new(:app_how_to_use.t, info_how_to_use_path,
                         html_options: { id: "nav_how_to_use_link" }).tab
      end

      def nav_donate_tab
        InternalLink.new(:app_donate.t, support_donate_path,
                         html_options: { id: "nav_donate_link" }).tab
      end

      def nav_how_to_help_tab
        InternalLink.new(:app_how_to_help.t, info_how_to_help_path,
                         html_options: { id: "nav_how_to_help_link" }).tab
      end

      def nav_report_a_bug_tab
        InternalLink.new(:app_report_a_bug.t,
                         new_admin_emails_webmaster_questions_path,
                         html_options: { id: "nav_bug_report_link" }).tab
      end

      def nav_send_a_comment_tab
        InternalLink.new(:app_send_a_comment.t,
                         new_admin_emails_webmaster_questions_path,
                         html_options: { id: "nav_ask_webmaster_link" }).tab
      end

      def nav_contributors_tab
        InternalLink.new(:app_contributors.t, contributors_path,
                         html_options: { id: "nav_contributors_link" }).tab
      end

      def nav_site_stats_tab
        InternalLink.new(:app_site_stats.t, info_site_stats_path,
                         html_options: { id: "nav_site_stats_link" }).tab
      end

      def nav_translators_note_tab
        InternalLink.new(:translators_note_title.t, info_translators_note_path,
                         html_options: { id: "nav_translators_note_link" }).tab
      end

      def nav_publications_tab
        InternalLink.new(:app_publications.t, publications_path,
                         html_options: { id: "nav_publications_link" }).tab
      end

      def nav_privacy_policy_tab
        InternalLink.new(:app_privacy_policy.t, policy_privacy_path,
                         html_options: { id: "nav_privacy_policy_link" }).tab
      end
    end
  end
end
