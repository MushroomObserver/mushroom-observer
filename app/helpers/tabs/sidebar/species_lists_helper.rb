# frozen_string_literal: true

module Tabs
  module Sidebar
    module SpeciesListsHelper
      def sidebar_species_lists_tabs(user)
        [
          nav_your_lists_tab(user),
          nav_all_lists_tab,
          nav_new_list_tab(user)
        ]
      end

      def nav_your_lists_tab(user)
        return unless user

        InternalLink.new(
          :app_your_lists.t,
          species_lists_path(by_user: user.id),
          html_options: { id: "nav_your_species_lists_link" }
        ).tab
      end

      def nav_all_lists_tab
        InternalLink.new(:app_all_lists.t, species_lists_path,
                         html_options: { id: "nav_species_lists_link" }).tab
      end

      def nav_new_list_tab(user)
        return unless user

        InternalLink.new(:app_create_list.t, new_species_list_path,
                         html_options: { id: "nav_new_species_list_link" }).tab
      end
    end
  end
end
