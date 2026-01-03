# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Species Lists" section of the sidebar with species list links
    #
    # @example Basic usage
    #   render(Components::Sidebar::SpeciesLists.new(
    #     user: current_user, classes: sidebar_css_classes
    #   ))
    #
    class SpeciesLists < Section
      include Tabs::Sidebar::SpeciesListsHelper

      private

      def heading_key
        :app_species_list
      end

      def tabs_method
        :sidebar_species_lists_tabs
      end
    end
  end
end
