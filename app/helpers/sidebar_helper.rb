# frozen_string_literal: true

module SidebarHelper
  # All helpers are autoloaded under Zeitwerk
  def sidebar_css_classes
    {
      wrapper: "navbar navbar-inverse sidebar-nav list-group",
      heading: "list-group-item disabled font-weight-bold",
      item: "list-group-item",
      admin: "list-group-item list-group-item-danger indent",
      indent: "list-group-item indent",
      mobile_only: "visible-xs",
      desktop_only: "hidden-xs"
    }.freeze
  end
end
