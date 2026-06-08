# frozen_string_literal: true

# The per-page "Actions" dropdown that lives in the top-nav,
# next to the page title — the desktop-only context-nav. On
# desktop the top nav IS the context nav. The visible label is
# `:app_context_actions.l` ("Actions"). Rendered into
# `content_for(:context_nav)` by
# `Header::ContextNavHelper#add_context_nav(links)`.
#
# The mobile-only counterpart lives at
# `Views::Layouts::Sidebar::ContextNav` — same tuple shape, same
# dispatch logic (via `Views::Layouts::ContextNav::LinkRendering`),
# different layout container.
#
# Wraps `Components::Dropdown` — the Bootstrap nav-dropdown
# markup, toggle, and per-item link/button dispatch all live
# there. This view just configures the dropdown for the Actions
# use case.
class Views::Layouts::TopNav::ContextNav < Views::Base
  prop :links, _Union(Array, ::Tab::Base, ::Tab::Collection)

  def view_template
    render(Components::Dropdown.new(
             id: "context_nav_toggle",
             menu_id: "context_nav",
             label: :app_context_actions.l
           )) do |menu|
      menu.section(@links)
    end
  end
end
