# frozen_string_literal: true

module Tabs
  module AccountHelper
    def account_welcome_title(user = nil)
      if user
        :email_welcome.t(user: user.legal_name)
      else
        :welcome_no_user_title.t
      end
    end

    def account_profile_edit_tabs
      [
        account_bulk_license_updater_tab,
        account_show_notifications_tab,
        account_edit_preferences_tab,
        account_show_api_keys_tab
      ]
    end

    def account_preferences_edit_tabs
      [
        account_bulk_license_updater_tab,
        account_change_image_vote_anonymity_tab,
        account_edit_profile_tab,
        account_show_notifications_tab,
        account_show_api_keys_tab
      ]
    end

    def account_api_tabs
      [
        account_edit_preferences_tab,
        account_edit_profile_tab
      ]
    end

    def account_edit_preferences_tab
      [:prefs_link.t, edit_account_preferences_path,
       { class: tab_id(__method__.to_s) }]
    end

    def account_edit_profile_tab
      [:profile_link.t, edit_account_profile_path,
       { class: tab_id(__method__.to_s) }]
    end

    def account_bulk_license_updater_tab
      [:bulk_license_link.t, images_edit_licenses_path,
       { class: tab_id(__method__.to_s) }]
    end

    def account_show_notifications_tab
      [:show_user_your_notifications.t, interests_path,
       { class: tab_id(__method__.to_s) }]
    end

    def account_show_api_keys_tab
      [:account_api_keys_link.t, account_api_keys_path,
       { class: tab_id(__method__.to_s) }]
    end

    def account_change_image_vote_anonymity_tab
      [:prefs_change_image_vote_anonymity.t,
       images_edit_vote_anonymity_path,
       { class: tab_id(__method__.to_s) }]
    end
  end
end
