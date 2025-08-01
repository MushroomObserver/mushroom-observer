# frozen_string_literal: true

module Tabs
  module UserNavHelper
    def user_logged_in_tabs(user)
      [
        user_observations_tab(user, :app_your_observations.t),
        comments_for_user_tab(user, :app_comments_for_you.t),
        projects_for_user_tab(user),
        species_lists_for_user_tab(user),
        account_show_interests_tab,
        account_edit_profile_tab,
        account_edit_preferences_tab
      ]
    end

    def user_log_out_tabs
      [
        admin_mode_tab,
        logout_tab
      ]
    end

    def admin_mode_tab
      if in_admin_mode?
        admin_title = :app_turn_admin_off.t
        admin_mode_args = { turn_off: true }
      else
        admin_title = :app_turn_admin_on.t
        admin_mode_args = { turn_on: true }
      end

      InternalLink.new(
        admin_title, admin_mode_path(**admin_mode_args),
        html_options: { id: "user_nav_admin_mode_link", button: :post }
      ).tab
    end

    def logout_tab
      InternalLink.new(
        :app_logout.l, account_logout_path,
        html_options: { id: "user_nav_logout_link", button: :post }
      ).tab
    end
  end
end
