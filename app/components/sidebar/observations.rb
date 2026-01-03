# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Observations" section of the sidebar with observation links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Observations.new(
    #     user: current_user, classes: sidebar_css_classes
    #   ))
    #
    class Observations < Section
      include Tabs::Sidebar::ObservationsHelper

      private

      def heading_key
        :app_observations_left
      end

      def tabs_method
        :sidebar_observations_tabs
      end
    end
  end
end
