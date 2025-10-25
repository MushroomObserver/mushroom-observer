# frozen_string_literal: true

module Tabs
  module Sidebar
    module UserHelper
      def sidebar_user_tabs(user)
        [
          comments_for_user_tab(user, :app_comments_for_you.t),
          account_show_interests_tab,
          user_summary_tab(user),
          account_edit_preferences_tab,
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
