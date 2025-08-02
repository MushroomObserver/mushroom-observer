# frozen_string_literal: true

module Tabs
  module SidebarHelper
    def sidebar_observations_tabs(user)
      [
        nav_latest_observations_tab,
        nav_new_observation_tab(user),
        nav_your_observations_tab(user),
        nav_identify_observations_tab(user)
      ]
    end

    def nav_latest_observations_tab
      InternalLink.new(:app_latest.t, root_path,
                       html_options: { id: "nav_observations_link" }).tab
    end

    def nav_new_observation_tab(user)
      return unless user

      InternalLink.new(:app_create_observation.t, new_observation_path,
                       html_options: { id: "nav_new_observation_link" }).tab
    end

    def nav_your_observations_tab(user)
      return unless user

      InternalLink.new(:app_your_observations.t,
                       observations_path(by_user: user.id),
                       html_options: { id: "nav_your_observations_link" }).tab
    end

    def nav_identify_observations_tab(user)
      return unless user

      InternalLink.new(
        :app_help_id_obs.t, identify_observations_path,
        html_options: { id: "nav_identify_observations_link" }
      ).tab
    end

    def sidebar_species_lists_tabs(user)
      [
        nav_your_lists_tab(user),
        nav_all_lists_tab,
        nav_new_list_tab(user)
      ]
    end

    def nav_your_lists_tab(user)
      return unless user

      InternalLink.new(:app_your_lists.t,
                       species_lists_path(by_user: user.id),
                       html_options: { id: "nav_your_species_lists_link" }).tab
    end

    def nav_all_lists_tab
      InternalLink.new(:app_all_lists.t, species_lists_path,
                       html_options: { id: "nav_species_lists_link" }).tab
    end

    def nav_new_list_tab(user)
      return unless user

      InternalLink.new(:app_create_list.t, new_species_list_path,
                       html_options: { id: "nav_new_species_list_link" }).tab
    end

    def sidebar_latest_tabs(user)
      [
        nav_latest_news_tab,
        nav_latest_changes_tab(user),
        nav_latest_images_tab(user),
        nav_latest_comments_tab(user)
      ]
    end

    def nav_latest_news_tab
      InternalLink.new(:NEWS.t, articles_path,
                       html_options: { id: "nav_articles_link" }).tab
    end

    def nav_latest_changes_tab(user)
      return unless user

      InternalLink.new(:app_latest_changes.t, activity_logs_path,
                       html_options: { id: "nav_activity_logs_link" }).tab
    end

    def nav_latest_images_tab(user)
      return unless user

      InternalLink.new(:app_newest_images.t, images_path,
                       html_options: { id: "nav_images_link" }).tab
    end

    def nav_latest_comments_tab(user)
      return unless user

      InternalLink.new(:app_comments.t, comments_path,
                       html_options: { id: "nav_comments_link" }).tab
    end

    def sidebar_indexes_tabs
      [
        nav_glossary_tab,
        nav_herbaria_tab,
        nav_locations_tab,
        nav_names_tab,
        nav_projects_tab
      ]
    end

    def nav_glossary_tab
      InternalLink.new(:GLOSSARY.t, glossary_terms_path,
                       html_options: { id: "nav_articles_link" }).tab
    end

    def nav_herbaria_tab
      InternalLink.new(:HERBARIA.t, herbaria_path,
                       html_options: { id: "nav_herbaria_link" }).tab
    end

    def nav_locations_tab
      InternalLink.new(:LOCATIONS.t, locations_path,
                       html_options: { id: "nav_locations_link" }).tab
    end

    def nav_names_tab
      InternalLink.new(:NAMES.t, names_path(has_observations: true),
                       html_options: { id: "nav_name_observations_link" }).tab
    end

    def nav_projects_tab
      InternalLink.new(:PROJECTS.t, projects_path,
                       html_options: { id: "nav_projects_link" }).tab
    end

    def sidebar_info_tabs
      [
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
