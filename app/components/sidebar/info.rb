# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "More" section of the sidebar with informational links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Info.new(classes: sidebar_css_classes))
    #
    class Info < Section
      include Tabs::Sidebar::InfoHelper

      private

      def heading_key
        :app_more
      end

      def tabs_method
        :sidebar_info_tabs
      end
    end
  end
end
