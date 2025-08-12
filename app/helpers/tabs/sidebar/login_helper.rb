# frozen_string_literal: true

module Tabs
  module Sidebar
    module LoginHelper
      def sidebar_login_tabs
        [
          login_tab,
          signup_tab
        ]
      end

      def login_tab
        InternalLink.new(
          :app_login.t, new_account_login_path,
          html_options: { id: "nav_login_link" }
        ).tab
      end

      def signup_tab
        InternalLink.new(
          :app_create_account.t, account_signup_path,
          html_options: { id: "nav_signup_link" }
        ).tab
      end
    end
  end
end
