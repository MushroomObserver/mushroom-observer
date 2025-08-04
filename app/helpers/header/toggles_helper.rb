# frozen_string_literal: true

#  search_nav_toggle            # toggle the collapsible search_nav
#  left_nav_toggle              # toggle the left nav on mobile
#
module Header
  module TogglesHelper
    def search_nav_toggle
      tag.div(class: "navbar-form px-sm-3") do
        tag.button(
          link_icon(:search, title: :SEARCH.l),
          class: "btn btn-sm btn-outline-default",
          type: :button,
          data: { toggle: "collapse", target: "#search_nav" },
          aria: { expanded: "false", controls: "search_nav" }
        )
      end
    end

    def left_nav_toggle
      tag.div(class: "visible-xs visible-sm pr-3 pr-sm-4") do
        tag.button(
          # link_icon(:menu, title: :MENU.l),
          image_tag("mo_icon_bg.svg",
                    width: "30px", alt: :MENU.t, title: :MENU.t),
          class: "btn btn-outline-default rounded-circle overflow-hidden p-0",
          type: :button, id: "left_nav_toggle",
          data: { toggle: "offcanvas", nav_target: "toggle",
                  action: "nav#toggleOffcanvas" },
          aria: { expanded: "false", controls: "search_nav" }
        )
      end
    end
  end
end
