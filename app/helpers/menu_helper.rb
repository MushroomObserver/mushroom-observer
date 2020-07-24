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
        link_to(:app_your_summary.t,
                user_path(id: @user.id)),
        link_to(:app_preferences.t,
                account_prefs_path),
        link_to(:app_join_mailing_list.t,
                "https://groups.google.com/forum/?fromgroups=#!forum/mo-general"),
        link_to(:app_turn_admin_on.t,
                account_turn_admin_on_path),
        link_to(:app_logout.t,
                account_logout_user_path)
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
end
