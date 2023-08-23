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

    def account_profile_edit_links
      [
        account_bulk_license_updater_link,
        account_show_notifications_link,
        account_edit_preferences_link,
        account_show_api_keys_link
      ]
    end

    def account_preferences_edit_links
      [
        account_bulk_license_updater_link,
        account_change_image_vote_anonymity_link,
        account_edit_profile_link,
        account_show_notifications_link,
        account_show_api_keys_link
      ]
    end

    def account_api_links
      [
        account_edit_preferences_link,
        account_edit_profile_link
      ]
    end

    def account_edit_preferences_link
      [:prefs_link.t, edit_account_preferences_path,
       { class: __method__.to_s }]
    end

    def account_edit_profile_link
      [:profile_link.t, edit_account_profile_path,
       { class: __method__.to_s }]
    end

    def account_bulk_license_updater_link
      [:bulk_license_link.t, images_license_updater_path,
       { class: __method__.to_s }]
    end

    def account_show_notifications_link
      [:show_user_your_notifications.t, interests_path,
       { class: __method__.to_s }]
    end

    def account_show_api_keys_link
      [:account_api_keys_link.t, account_api_keys_path,
       { class: __method__.to_s }]
    end

    def account_change_image_vote_anonymity_link
      [:prefs_change_image_vote_anonymity.t,
       images_edit_vote_anonymity_path,
       { class: __method__.to_s }]
    end
  end
end
