# frozen_string_literal: true

module Components
  # Renders a welcome/description layout for login pages
  #
  # Displays MO logo (mobile only) and description text for unverified users
  #
  # @example Basic usage
  #   <%= render(Components::LoginLayout.new) %>
  #
  class LoginLayout < Base
    def view_template
      comment { "LOGIN LAYOUT" }
      div(class: "container-text") do
        div(class: "text-center visible-xs-block") do
          img(class: "logo-trim", alt: "MO Logo", src: "/logo-trim.png")
        end
        h2(class: "h3 text-center") { plain("Mushroom Observer (MO)") }
        p { plain(:login_layout_description.t) }
      end
      comment { "/LOGIN LAYOUT" }
    end
  end
end
