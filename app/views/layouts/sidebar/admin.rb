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
    def view_template
      render(Components::ListGroup::Item.new(class: @classes[:heading])) do
        plain("#{@heading_key.t}:")
      end

      @tabs.compact.each do |link|
        render_nav_link(link, link_class: @classes[:admin])
      end

      render_admin_mode_toggle
    end

    private

    # Toggling admin mode changes the session's theme/asset state,
    # so Turbo Drive's head-merging on the redirected page can
    # corrupt stylesheets. `Tab::UserNav::AdminMode` already opts out
    # of Turbo for this reason — source everything from it instead of
    # re-typing the title/path/opt-out (this is also what the desktop
    # user-nav dropdown renders).
    def render_admin_mode_toggle
      tab = Tab::UserNav::AdminMode.new(in_admin_mode: true)
      render(
        Components::ListGroup::LinkItem.new(class: @classes[:admin])
      ) do |css_class|
        Button(
          type: :post,
          name: tab.title,
          target: tab.path,
          variant: :link,
          class: class_names(css_class, tab.html_options[:class]),
          data: tab.html_options[:data]
        )
      end
    end
  end
end
