# frozen_string_literal: true

# Component for rendering collapsible panel body content.
# Wraps body content in a Bootstrap collapsible div.
#
# @example Basic collapsible body
#   render Components::PanelCollapseBody.new(
#     id: "my_panel_body",
#     open: true
#   ) do
#     "Collapsible content"
#   end
#
# @example Closed collapsible body
#   render Components::PanelCollapseBody.new(
#     id: "details_panel",
#     open: false
#   ) do
#     panel.render Components::PanelBody.new { "Hidden content" }
#   end
class Components::PanelCollapseBody < Components::Base
  prop :id, String
  prop :open, _Boolean, default: false

  def view_template
    div(
      class: class_names("panel-collapse collapse", @open ? "in" : nil),
      id: @id
    ) do
      yield if block_given?
    end
  end
end
