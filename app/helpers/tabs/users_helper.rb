# frozen_string_literal: true

module Tabs
  module UsersHelper
    def user_show_tabs
      [site_contributors_tab]
    end

    def user_profile_tabs(show_user:, user:)
      links = []
      links += if show_user == user
                 links_for_this_user(show_user)
               else
                 links_for_that_user(show_user)
               end
      return links unless in_admin_mode?

      links += user_tabs_for_admin(show_user)

      links
    end

    def users_index_sorts(admin: false)
      return admin_users_index_sorts if admin

      regular_users_index_sorts
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
        comments_for_user_tab(user)
        # email_user_question_tab(user)
      ]
    end

    def user_life_list_tab(user)
      InternalLink::Model.new(:app_life_list.t, user,
                              checklist_path(id: user.id)).tab
    end

    def user_profile_tab(user)
      InternalLink::Model.new(:show_object.t(type: :profile), user,
                              user_path(user.id)).tab
    end

    # Same as above with "Your summary" caption
    def user_summary_tab(user)
      InternalLink::Model.new(:app_your_summary.l, user,
                              user_path(user.id)).tab
    end

    def user_observations_tab(user, text = nil)
      text ||= :show_user_observations_by.t(name: user.text_name)
      InternalLink::Model.new(text, user,
                              observations_path(by_user: user.id)).tab
    end

    def comments_for_user_tab(user, text = nil)
      text ||= :show_user_comments_for.t(name: user.text_name)
      InternalLink::Model.new(text, user, comments_path(for_user: user.id)).tab
    end

    def email_user_question_tab(user)
      InternalLink::Model.new(
        :show_user_email_to.t(name: user.unique_text_name),
        user, new_question_for_user_path(user.id),
        html_options: { icon: :email }
      ).tab
    end

    def user_tabs_for_admin(user)
      [
        admin_change_user_bonuses_tab(user),
        admin_destroy_user_tab(user)
      ]
    end

    def admin_change_user_bonuses_tab(user)
      InternalLink::Model.new(:change_user_bonuses.t,
                              user, edit_admin_user_path(user.id)).tab
    end

    def admin_destroy_user_tab(user)
      InternalLink::Model.new(:destroy_object.t(TYPE: User),
                              user, admin_user_path(id: user.id),
                              html_options: { button: :destroy }).tab
    end

    def regular_users_index_sorts
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
        ["id",            :sort_by_id.t],
        ["login",         :sort_by_login.t],
        ["name",          :sort_by_name.t],
        ["created_at",    :sort_by_created_at.t],
        ["updated_at",    :sort_by_updated_at.t],
        ["last_login",    :sort_by_last_login.t],
        ["contribution",  :sort_by_contribution.t]
      ].freeze
    end
  end
end
