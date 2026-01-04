# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Account" section of the sidebar for non-logged-in users
    #
    # @example Basic usage
    #   render(Components::Sidebar::Login.new(
    #     heading_key: :app_account,
    #     tabs: sidebar_login_tabs,
    #     classes: sidebar_css_classes
    #   ))
    #
    class Login < Section
      def view_template
        div(class: @classes[:heading]) do
          i(class: "glyphicon glyphicon-user")
          span { plain("#{@heading_key.t}:") }
        end

        tabs_array.compact.each do |link|
          render_nav_link(link)
        end
      end
    end
  end
end
