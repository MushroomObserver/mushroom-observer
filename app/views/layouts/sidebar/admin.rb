# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the "Admin" section of the sidebar for admin users in admin
  # mode.
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::Admin.new(
  #     heading_key: :app_admin,
  #     tabs: Tab::Sidebar::AdminActions.new.map(&:to_a),
  #     classes: Views::Layouts::Sidebar::CSS_CLASSES
  #   ))
  class Admin < Section
    include Rails.application.routes.url_helpers

    def view_template
      div(class: @classes[:heading]) do
        plain("#{@heading_key.t}:")
      end

      @tabs.compact.each do |link|
        render_nav_link(link, link_class: @classes[:admin])
      end

      Button(
        type: :post,
        name: :app_turn_admin_off.t,
        target: admin_mode_path(turn_off: true),
        variant: :btn_link,
        id: "nav_admin_off_link",
        class: @classes[:admin]
      )
    end
  end
end
