# frozen_string_literal: true

# A `<button type="button">` with two text states toggled by a CSS
# class on a parent element. Renders an optional icon followed by a
# show-state span and a hide-state span; CSS on the parent shows or
# hides each span depending on the toggle state.
#
# @example Map expand/collapse toggle (parent adds `.map-open`)
#   render(Components::Button::Toggle.new(
#     show_text: :form_observations_open_map.l,
#     hide_text: :form_observations_hide_map.l,
#     show_class: "map-show",
#     hide_class: "map-hide",
#     icon: :globe,
#     class: "map-toggle",
#     data: { map_target: "toggleMapBtn", ... },
#     aria: { expanded: "false", controls: id }
#   ))
class Components::Button::Toggle < Components::Button
  def initialize(show_text:, hide_text:, show_class:, hide_class:, **)
    super(name: show_text, **)
    @show_text = show_text
    @hide_text = hide_text
    @show_class = show_class
    @hide_class = hide_class
  end

  private

  def button_content
    render(Components::Icon.new(type: @icon, html_class: @icon_class)) if @icon
    span(class: class_names(@show_class, "mx-2")) { plain(@show_text) }
    span(class: class_names(@hide_class, "mx-2")) { plain(@hide_text) }
  end
end
