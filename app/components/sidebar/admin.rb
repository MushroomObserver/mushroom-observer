# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the "Admin" section of the sidebar for admin users in admin mode
    #
    # @example Basic usage
    #   render(Components::Sidebar::Admin.new(
    #     heading_key: :app_admin,
    #     tabs: sidebar_admin_tabs,
    #     classes: sidebar_css_classes
    #   ))
    #
    class Admin < Section
      include Rails.application.routes.url_helpers

      def view_template
        div(class: @classes[:heading]) do
          plain("#{@heading_key.t}:")
        end

        tabs_array.compact.each do |link|
          render_nav_link(link, link_class: @classes[:admin])
        end

        trusted_html(
          button_to(
            :app_turn_admin_off.t,
            admin_mode_path(turn_off: true),
            class: class_names(@classes[:admin], "btn btn-link"),
            id: "nav_admin_off_link",
            method: :post
          )
        )
      end
    end
  end
end
