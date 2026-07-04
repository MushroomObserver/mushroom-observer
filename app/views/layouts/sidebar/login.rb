# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the "Account" section of the sidebar for non-logged-in
  # users.
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::Login.new(
  #     heading_key: :app_account,
  #     tabs: Tab::Sidebar::LoginActions.new.map(&:to_a),
  #     classes: Views::Layouts::Sidebar::CSS_CLASSES
  #   ))
  class Login < Section
    def view_template
      div(class: @classes[:heading]) do
        Icon(type: :user)
        span { plain("#{@heading_key.t}:") }
      end

      @tabs.compact.each do |link|
        render_nav_link(link)
      end
    end
  end
end
