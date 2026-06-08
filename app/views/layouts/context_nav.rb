# frozen_string_literal: true

# Shared namespace for the per-page "Actions" menu — the
# right-side dropdown next to the page title (labeled
# `:app_context_actions.l` → "Actions") and the equivalent
# block in the mobile offcanvas sidebar.
#
# The actual rendering classes live next to the layout
# containers they render into:
#   - `Views::Layouts::TopNav::ContextNav` — desktop top-nav
#     dropdown (`content_for(:context_nav)`)
#   - `Views::Layouts::Sidebar::ContextNav` — mobile sidebar
#     block (`content_for(:context_nav_mobile)`)
#
# Both are populated by `Header::ContextNavHelper#add_context_nav`
# and share the dispatch logic in `LinkRendering`.
module Views::Layouts::ContextNav
end
