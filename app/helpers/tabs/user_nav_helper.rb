# frozen_string_literal: true

module Tabs
  module UserNavHelper
    def user_logged_in_tabs(user)
      [
        ::Tab::User::Observations.new(
          user: user, text: :app_your_observations.t
        ).to_a,
        ::Tab::User::CommentsFor.new(
          user: user, text: :app_comments_for_you.t
        ).to_a,
        ::Tab::Project::ForUser.new(user: user).to_a,
        ::Tab::SpeciesList::ForUser.new(user: user).to_a,
        ::Tab::Account::ShowInterests.new.to_a,
        ::Tab::Account::EditProfile.new.to_a,
        ::Tab::Account::EditPreferences.new.to_a
      ]
    end

    def user_log_out_tabs(user)
      [
        admin_mode_tab,
        logout_tab(user)
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

    def logout_tab(user)
      return unless user

      InternalLink.new(
        :app_logout.l, account_logout_path,
        html_options: { id: "user_nav_logout_link", button: :post }
      ).tab
    end
  end
end
