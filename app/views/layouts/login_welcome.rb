# frozen_string_literal: true

# Welcome/description banner shown to unverified users — MO logo
# (mobile only) and description text. Currently uncalled: the render
# site is commented out (an `unless @user&.verified?` block);
# keeping the class around for when that's
# re-enabled. Renamed from `Components::LoginLayout` since it's not
# really a layout — it's app-wide chrome that *the* layout was
# expected to render.
#
# @example Re-enabling in the application layout
#   <% unless @user&.verified? %>
#     <%= render(Views::Layouts::LoginWelcome.new) %>
#   <% end %>
module Views::Layouts
  class LoginWelcome < Views::Base
    def view_template
      comment { "LOGIN WELCOME" }
      div(class: "container-text") do
        div(class: "text-center visible-xs-block") do
          img(class: "logo-trim", alt: "MO Logo", src: "/logo-trim.png")
        end
        h2(class: "h3 text-center") { plain("Mushroom Observer (MO)") }
        p { plain(:login_layout_description.t) }
      end
      comment { "/LOGIN WELCOME" }
    end
  end
end
