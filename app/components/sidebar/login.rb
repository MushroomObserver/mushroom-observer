# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Account" section of the sidebar for non-logged-in users
    #
    # @example Basic usage
    #   render(Components::Sidebar::Login.new(classes: sidebar_css_classes))
    #
    class Login < Section
      include Tabs::Sidebar::LoginHelper

      def view_template
        div(class: @classes[:heading]) do
          i(class: "glyphicon glyphicon-user")
          span { plain("#{heading_key.t}:") }
        end

        tabs.compact.each do |link|
          render_nav_link(link)
        end
      end

      private

      def heading_key
        :app_account
      end

      def tabs_method
        :sidebar_login_tabs
      end
    end
  end
end
