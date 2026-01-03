# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "More" section of the sidebar with informational links
    #
    # @example Basic usage
    #   render(Components::Sidebar::Info.new(classes: sidebar_css_classes))
    #
    class Info < Components::Base
      include Tabs::Sidebar::InfoHelper

      prop :classes, _Hash(Symbol, String)

      # Register the active_link_to helper for navigation links
      register_output_helper :active_link_to

      def view_template
        div(class: @classes[:heading]) do
          plain("#{:app_more.t}:")
        end

        sidebar_info_tabs.compact.each do |link|
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
