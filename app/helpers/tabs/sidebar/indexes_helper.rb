# frozen_string_literal: true

module Tabs
  module Sidebar
    module IndexesHelper
      def sidebar_indexes_tabs
        [
          nav_glossary_tab,
          nav_herbaria_tab,
          nav_locations_tab,
          nav_names_tab,
          nav_projects_tab
        ]
      end

      def nav_glossary_tab
        InternalLink.new(:GLOSSARY.t, glossary_terms_path,
                         html_options: { id: "nav_articles_link" }).tab
      end

      def nav_herbaria_tab
        InternalLink.new(:HERBARIA.t, herbaria_path,
                         html_options: { id: "nav_herbaria_link" }).tab
      end

      def nav_locations_tab
        InternalLink.new(:LOCATIONS.t, locations_path,
                         html_options: { id: "nav_locations_link" }).tab
      end

      def nav_names_tab
        InternalLink.new(:NAMES.t, names_path(has_observations: true),
                         html_options: { id: "nav_name_observations_link" }).tab
      end

      def nav_projects_tab
        InternalLink.new(:PROJECTS.t, projects_path,
                         html_options: { id: "nav_projects_link" }).tab
      end
    end
  end
end
