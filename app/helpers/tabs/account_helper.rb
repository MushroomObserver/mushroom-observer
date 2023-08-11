# frozen_string_literal: true

module Tabs
  module AccountHelper
    def account_profile_edit_links
      [
        [:bulk_license_link.t, images_license_updater_path],
        [:show_user_your_notifications.t, interests_path],
        [:prefs_link.t, edit_account_preferences_path],
        [:account_api_keys_link.t, account_api_keys_path]
      ]
    end

    def account_preferences_edit_links
      [
        [:bulk_license_link.t, images_edit_licenses_path],
        [:prefs_change_image_vote_anonymity.t,
         images_edit_vote_anonymity_path],
        [:profile_link.t, edit_account_profile_path],
        [:show_user_your_notifications.t, interests_path],
        [:account_api_keys_link.t, account_api_keys_path]
      ]
    end

    def account_api_links
      [
        [:prefs_link.t, edit_account_preferences_path],
        [:profile_link.t, edit_account_profile_path]
      ]
    end
  end
end
