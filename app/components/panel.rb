# frozen_string_literal: true

# Component for rendering Bootstrap panels (cards).
#
# Accepts subcomponents in a block:
#   PanelHeading, PanelBody, PanelThumbnail, PanelFooter
#
# @example Basic panel with heading and body
#   render(Components::Panel.new do |panel|
#     panel.render Components::PanelHeading.new { "Title" }
#     panel.render Components::PanelBody.new { "Panel content" }
#   end)
#
# @example Panel with all subcomponents
#   render(Components::Panel.new do |panel|
#     panel.render(Components::PanelHeading.new { strong { "Title" } })
#     panel.render(Components::PanelThumbnail.new { image_tag("photo.jpg") })
#     panel.render(Components::PanelBody.new { "First section" })
#     panel.render(Components::PanelBody.new { "Second section" })
#     panel.render(Components::PanelFooter.new { "Footer text" })
#   end)
#
# @example Panel with custom class and ID
#   render(Components::Panel.new(
#     panel_class: "custom-panel",
#     inner_id: "my_panel"
#   ) do |panel|
#     panel.render(Components::PanelBody.new { "Content" })
#   end)
class Components::Panel < Components::Base
  prop :panel_class, _Nilable(String), default: nil
  prop :inner_id, _Nilable(String), default: nil
  prop :attributes, Hash, default: -> { {} }

  def view_template
    div(
      class: class_names("panel panel-default", @panel_class),
      id: @inner_id,
      **@attributes
    ) do
      yield if block_given?
    end
  end
end
