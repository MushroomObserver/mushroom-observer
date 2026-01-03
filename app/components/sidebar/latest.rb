# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Latest" section of the sidebar with recent activity links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Latest.new(user: current_user, classes: sidebar_css_classes))
    #
    class Latest < Components::Base
      include Tabs::Sidebar::LatestHelper

      prop :user, _Nilable(User)
      prop :classes, _Hash(Symbol, String)

      # Register the active_link_to helper for navigation links
      register_output_helper :active_link_to

      def view_template
        div(class: @classes[:heading]) do
          plain("#{:app_latest.t}:")
        end

        sidebar_latest_tabs(@user).compact.each do |link|
          render_nav_link(link)
        end
      end

      private

      def render_nav_link(link)
        title, url, html_options = link
        html_options ||= {}
        html_options[:class] = class_names(
          @classes[:indent],
          html_options[:class]
        )

        active_link_to(title, url, **html_options)
      end
    end
  end
end
