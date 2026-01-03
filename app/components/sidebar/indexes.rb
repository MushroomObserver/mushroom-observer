# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Indexes" section of the sidebar with index links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Indexes.new(classes: sidebar_css_classes))
    #
    class Indexes < Section
      include Tabs::Sidebar::IndexesHelper

      private

      def heading_key
        :INDEXES
      end

      def tabs_method
        :sidebar_indexes_tabs
      end
    end
  end
end
