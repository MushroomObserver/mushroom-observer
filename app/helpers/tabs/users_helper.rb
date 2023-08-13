# frozen_string_literal: true

module Tabs
  module UsersHelper
    def user_show_links(show_user:, user:)
      links = [site_contributors_link]
      links += if show_user == user
                 links_for_this_user(show_user)
               else
                 links_for_that_user(show_user)
               end
      return links unless in_admin_mode?

      links += user_links_for_admin(show_user)

      links
    end

    #########################################################

    private

    def links_for_this_user(user)
      [
        user_observations_link(user, :show_user_your_observations.t),
        comments_for_user_link(user, :show_user_comments_for_you.t),
        account_show_notifications_link,
        account_edit_profile_link,
        account_edit_preferences_link,
        user_life_list_link(user)
      ]
    end

    def links_for_that_user(user)
      [
        user_observations_link(user),
        comments_for_user_link(user),
        email_user_question_link(user)
      ]
    end

    def user_life_list_link(user)
      [:app_life_list.t, checklist_path(id: user.id),
       { class: __method__.to_s }]
    end

    def user_profile_link(user)
      [:show_object.t(type: :profile), user_path(user.id),
       { class: __method__.to_s }]
    end

    def user_observations_link(user, text = nil)
      text ||= :show_user_observations_by.t(name: user.unique_text_name)
      [text, observations_path(user: user.id),
       { class: __method__.to_s }]
    end

    def comments_for_user_link(user, text = nil)
      text ||= :show_user_comments_for.t(name: user.unique_text_name)
      [text, comments_path(for_user: user.id),
       { class: __method__.to_s }]
    end

    def email_user_question_link(user)
      [:show_user_email_to.t(name: user.unique_text_name),
       emails_ask_user_question_path(user.id),
       { class: __method__.to_s }]
    end

    def user_links_for_admin(user)
      [
        admin_change_user_bonuses_link(user),
        admin_destroy_user_link(user)
      ]
    end

    def admin_change_user_bonuses_link(user)
      [:change_user_bonuses.t, edit_admin_users_path(user.id),
       { class: __method__.to_s }]
    end

    def admin_destroy_user_link(user)
      [nil, admin_users_path(id: user.id), { button: :destroy }]
    end
  end
end
