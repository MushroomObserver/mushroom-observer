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
      InternalLink.new(:prefs_link.t, edit_account_preferences_path).tab
    end

    def account_edit_profile_tab
      InternalLink.new(:profile_link.t, edit_account_profile_path).tab
    end

    def account_bulk_license_updater_tab
      InternalLink.new(:bulk_license_link.t, images_edit_licenses_path).tab
    end

    def account_show_notifications_tab
      InternalLink.new(:show_user_your_notifications.t, interests_path).tab
    end

    # Note this is the same as the above, but says "Your interests"
    def account_show_interests_tab
      InternalLink.new(:app_your_interests.t, interests_path).tab
    end

    def account_show_api_keys_tab
      InternalLink.new(:account_api_keys_link.t, account_api_keys_path).tab
    end

    def account_change_image_vote_anonymity_tab
      InternalLink.new(:prefs_change_image_vote_anonymity.t,
                       images_edit_vote_anonymity_path).tab
    end
  end
end
