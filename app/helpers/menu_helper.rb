# frozen_string_literal: true

#
#  = Menu Helpers
#
#  These methods are available to all templates in the application:
#
################################################################################

module MenuHelper
  include ActionView::Helpers::UrlHelper

  def user_menu
    menu = {}
    menu[:name] = "user"
    if @user.nil?
      menu[:heading] = :app_account.t
      menu[:links] = [
        link_to(:app_login.t, account_login_path),
        link_to(:app_create_account.t, new_account_path)
      ]
    else
      menu[:heading] = h(@user.login)
      menu[:links] = [
        link_to(:app_comments_for_you.t,
                comments_show_comments_for_user_path(id: @user.id)),
        link_to(:app_your_observations.t,
                observations_observations_by_user_path(id: @user.id)),
        link_to(:app_your_interests.t,
                interests_list_interests_path),
        link_to(:app_your_summary.t, user_path(id: @user.id)),
        link_to(:app_preferences.t, account_prefs_path),
        link_to(:app_join_mailing_list.t,
              "https://groups.google.com/forum/?fromgroups=#!forum/mo-general"),
        link_to(:app_turn_admin_on.t, account_turn_admin_on_path),
        link_to(:app_logout.t, account_logout_user_path)
      ]
    end

    menu
  end

  def intro_menu
    menu = {}
    menu[:name] = "intro"
    menu[:heading] = :app_how_to_use.t
    menu[:links] = [
      link_to(:app_intro.t, info_intro_path),
      link_to(:app_how_to_use.t, info_how_to_use_path),
      link_to(:search_bar_help.t, info_search_bar_help_path),
      link_to(:GLOSSARY.t, glossary_terms_path),
      link_to(:app_privacy_policy.t, policy_privacy_path)
    ]

    menu
  end

  def admin_menu
    menu = {}
    menu[:name] = "admin"
    menu[:heading] = :app_admin.t
    menu[:links] = [
      link_to(:app_admin.t, account_blocked_ips_path),
      link_to(:app_users.t, users_users_by_name_path),
      link_to(:change_banner_title.t, rss_logs_change_banner_path),
      link_to(:app_email_all_users.t, email_email_features_path),
      link_to(:app_add_to_group.t, account_add_user_to_group_path),
      link_to(:account_manager_title.t, account_manager_path),
      link_to(:app_turn_admin_off.t, account_turn_admin_off_path)
    ]

    menu
  end

  def latest_menu
    menu = {}
    menu[:name] = "latest"
    menu[:heading] = :app_latest.t
    menu[:links] = [
      link_to(:OBSERVATIONS.t, observations_path),
      link_to(:app_latest_changes.t, rss_logs_path),
      link_to(:app_species_list.t, species_lists_path),
      link_to(:app_newest_images.t, images_path),
      link_to(:app_comments.t, comments_path),
      link_to(:HERBARIA.t, herbaria_path),
      link_to(:LOCATIONS.t, locations_path),
      link_to(:NAMES.t, names_observation_index_path),
      link_to(:NEWS.t, articles_path),
      link_to(:PROJECTS.t, projects_path)
    ]

    menu
  end

  def help_menu
    menu = {}
    menu[:name] = "help"
    menu[:heading] = :app_how_to_help.t
    menu[:links] = [
      link_to(:app_how_to_help.t, info_how_to_help_path),
      link_to(:app_donate.t, support_donate_path),
      link_to(:app_feature_tracker.t, pivotal_index_path),
      link_to(:app_send_a_comment.t, email_ask_webmaster_question_path),
      link_to(:app_contributors.t, users_users_by_contribution_path),
      link_to(:app_site_stats.t, info_show_site_stats_path),
      link_to(:translators_note_title.t, info_translators_note_path),
      link_to(:app_publications.t, publications_path)
    ]

    menu
  end

  def translations_menu
    menu = {}
    menu[:name] = "translations"
    menu[:heading] = :app_admin.t
    menu[:links] = [
      link_to(:app_admin.t, account_blocked_ips_path),
      link_to(:app_users.t, users_users_by_name_path),
      link_to(:change_banner_title.t, rss_logs_change_banner_path),
      link_to(:app_email_all_users.t, email_email_features_path),
      link_to(:app_add_to_group.t, account_add_user_to_group_path),
      link_to(:account_manager_title.t, account_manager_path),
      link_to(:app_turn_admin_off.t, account_turn_admin_off_path)
    ]

    menu
  end
end
