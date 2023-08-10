# frozen_string_literal: true

module Tabs
  module UsersHelper
    def user_show_links(show_user:, user:)
      name = show_user.unique_text_name
      id = show_user.id
      paths = user_stats_link_paths(show_user)

      links = [
        [:show_user_contributors.t, contributors_path,
         { class: "contributors_link" }]
      ]
      links += if show_user == user
                 links_for_this_user(paths)
               else
                 links_for_that_user(paths, name, id)
               end
      return links unless in_admin_mode?

      links += user_links_for_admin(id)

      links
    end

    #########################################################

    private

    def links_for_this_user(paths)
      [
        [:show_user_your_observations.t, paths[:observations],
         { class: "user_observations_link" }],
        [:show_user_comments_for_you.t, paths[:comments_for],
         { class: "comments_for_user_link" }],
        [:show_user_your_notifications.t, interests_path,
         { class: "notifications_for_user_link" }],
        [:show_user_edit_profile.t, edit_account_profile_path,
         { class: "edit_account_profile_link" }],
        [:app_preferences.t, edit_account_preferences_path,
         { class: "edit_account_preferences_link" }],
        [:app_life_list.t, paths[:life_list],
         { class: "life_list_link" }]
      ]
    end

    def links_for_that_user(paths, name, id)
      [
        [:show_user_observations_by.t(name: name), paths[:observations],
         { class: "user_observations_link" }],
        [:show_user_comments_for.t(name: name), paths[:comments_for],
         { class: "comments_for_user_link" }],
        [:show_user_email_to.t(name: name),
         emails_ask_user_question_path(id: id),
         { class: "email_user_question_link" }]
      ]
    end

    def user_links_for_admin(id)
      [
        [:change_user_bonuses.t, edit_admin_users_path(id),
         { class: "change_user_bonuses_link" }],
        [nil, admin_users_path(id: id), { button: :destroy }]
      ]
    end
  end
end
