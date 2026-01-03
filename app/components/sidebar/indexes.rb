# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Indexes" section of the sidebar with index links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Indexes.new(classes: sidebar_css_classes))
    #
    class Indexes < Components::Base
      include Tabs::Sidebar::IndexesHelper

      prop :classes, _Hash(Symbol, String)

      # Register the active_link_to helper for navigation links
      register_output_helper :active_link_to

      def view_template
        div(class: @classes[:heading]) do
          plain("#{:INDEXES.t}:")
        end

        sidebar_indexes_tabs.compact.each do |link|
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
