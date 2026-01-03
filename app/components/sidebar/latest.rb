# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Latest" section of the sidebar with recent activity links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Latest.new(
    #     user: current_user, classes: sidebar_css_classes
    #   ))
    #
    class Latest < Section
      include Tabs::Sidebar::LatestHelper

      private

      def heading_key
        :app_latest
      end

      def tabs_method
        :sidebar_latest_tabs
      end
    end
  end
end
