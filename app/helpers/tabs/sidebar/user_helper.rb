# frozen_string_literal: true

module Tabs
  module Sidebar
    module UserHelper
      def sidebar_user_tabs(user)
        [
          ::Tab::User::CommentsFor.new(
            user: user, text: :app_comments_for_you.t
          ).to_a,
          ::Tab::Account::ShowInterests.new.to_a,
          ::Tab::User::Summary.new(user: user).to_a,
          ::Tab::Account::EditPreferences.new.to_a,
          join_mailing_list_tab
        ]
      end

      def join_mailing_list_tab
        InternalLink.new(
          :app_join_mailing_list.t,
          "https://groups.google.com/forum/?fromgroups=#!forum/mo-general",
          html_options: { id: "nav_join_mailing_list_link" }
        ).tab
      end
    end
  end
end
