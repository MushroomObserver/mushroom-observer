# frozen_string_literal: true

# Namespace for the application sidebar's Phlex partials
# (`Admin`, `Login`, `Section`, `User`, `Languages`). The frozen
# `CSS_CLASSES` hash is the canonical Bootstrap class set the
# desktop sidebar (`Views::Layouts::ApplicationSidebar`) passes to
# each partial via the `classes:` prop, and that
# `Components::ContextNav::Sidebar` reuses for its mobile rendering
# into the same offcanvas sidebar.
module Views::Layouts::Sidebar
  CSS_CLASSES = {
    wrapper: "navbar navbar-inverse sidebar-nav list-group",
    heading: "list-group-item disabled font-weight-bold",
    item: "list-group-item",
    admin: "list-group-item list-group-item-danger indent",
    indent: "list-group-item indent",
    mobile_only: "visible-xs",
    desktop_only: "hidden-xs"
  }.freeze
end
