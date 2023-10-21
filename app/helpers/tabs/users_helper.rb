# frozen_string_literal: true

module Tabs
  module UsersHelper
    def user_show_tabs(show_user:, user:)
      links = [site_contributors_tab]
      links += if show_user == user
                 links_for_this_user(show_user)
               else
                 links_for_that_user(show_user)
               end
      return links unless in_admin_mode?

      links += user_tabs_for_admin(show_user)

      links
    end

    #########################################################

    private

    def links_for_this_user(user)
      [
        user_observations_tab(user, :show_user_your_observations.t),
        comments_for_user_tab(user, :show_user_comments_for_you.t),
        account_show_notifications_tab,
        account_edit_profile_tab,
        account_edit_preferences_tab,
        user_life_list_tab(user)
      ]
    end

    def links_for_that_user(user)
      [
        user_observations_tab(user),
        comments_for_user_tab(user),
        email_user_question_tab(user)
      ]
    end

    def user_life_list_tab(user)
      [:app_life_list.t, checklist_path(id: user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def user_profile_tab(user)
      [:show_object.t(type: :profile), user_path(user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def user_observations_tab(user, text = nil)
      text ||= :show_user_observations_by.t(name: user.unique_text_name)
      [text, observations_path(user: user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def comments_for_user_tab(user, text = nil)
      text ||= :show_user_comments_for.t(name: user.unique_text_name)
      [text, comments_path(for_user: user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def email_user_question_tab(user)
      [:show_user_email_to.t(name: user.unique_text_name),
       emails_ask_user_question_path(user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def user_tabs_for_admin(user)
      [
        admin_change_user_bonuses_tab(user),
        admin_destroy_user_tab(user)
      ]
    end

    def admin_change_user_bonuses_tab(user)
      [:change_user_bonuses.t, edit_admin_users_path(user.id),
       { class: tab_id(__method__.to_s) }]
    end

    def admin_destroy_user_tab(user)
      [nil, admin_users_path(id: user.id), { button: :destroy }]
    end

    def users_index_sorts(admin)
      return admin_users_index_sorts if admin

      regular_user_index_sorts
    end

    def regular_user_index_sorts
      [
        ["login",         :sort_by_login.t],
        ["name",          :sort_by_name.t],
        ["created_at",    :sort_by_created_at.t],
        ["location",      :sort_by_location.t],
        ["contribution",  :sort_by_contribution.t]
      ].freeze
    end

    def admin_users_index_sorts
      [
        ["id",          :sort_by_id.t],
        ["login",       :sort_by_login.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["last_login",  :sort_by_last_login.t]
      ].freeze
    end
  end
end
