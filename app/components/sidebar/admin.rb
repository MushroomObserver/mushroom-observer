# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Admin" section of the sidebar for admin users in admin mode
    #
    # @example Basic usage
    #   render(Components::Sidebar::Admin.new(classes: sidebar_css_classes))
    #
    class Admin < Section
      include Tabs::Sidebar::AdminHelper

      include Rails.application.routes.url_helpers

      def view_template
        div(class: @classes[:heading]) do
          plain("#{:app_admin.t}:")
        end

        tabs.compact.each do |link|
          render_nav_link(link, link_class: @classes[:admin])
        end

        # rubocop:disable Rails/OutputSafety
        raw(
          button_to(
            :app_turn_admin_off.t,
            admin_mode_path(turn_off: true),
            class: [@classes[:admin], "btn btn-link"],
            id: "nav_admin_off_link",
            method: :post
          )
        )
        # rubocop:enable Rails/OutputSafety
      end

      private

      def heading_key
        :app_admin
      end

      def tabs_method
        :sidebar_admin_tabs
      end
    end
  end
end
