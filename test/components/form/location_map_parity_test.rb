# frozen_string_literal: true

require("test_helper")

# Pre-refactor implementation of the map toggle button.
# Recreates the deleted `Button::Toggle` component that used
# CSS-class-based show/hide spans. The new `Button::CollapseToggle`
# uses `span.collapse-toggle-open` / `span.collapse-toggle-closed`
# instead, driven by Bootstrap's `.collapsed` class on the trigger.
class ToggleOld < Components::Button
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

# Compares the deleted `Button::Toggle` output against the new
# `Button::CollapseToggle`. Element type is the same (`<button>`);
# the intentional change is the span class names used for show/hide.
class Components::Form::LocationMapParityTest < ComponentTestCase
  # Both components render a `<button>` with the same data attributes
  # for Bootstrap collapse and Stimulus wiring. The span class names
  # that control show/hide state changed from `.map-show` / `.map-hide`
  # to `.collapse-toggle-open` / `.collapse-toggle-closed`.
  def test_toggle_button_behavioral_attributes_preserved
    old_html = render(ToggleOld.new(
                        show_text: :form_observations_open_map.l,
                        hide_text: :form_observations_hide_map.l,
                        show_class: "map-show",
                        hide_class: "map-hide",
                        icon: :globe,
                        class: "map-toggle",
                        data: {
                          map_target: "toggleMapBtn",
                          action: "map#toggleMap form-exif#showFields",
                          toggle: "collapse",
                          target: "#obs_map"
                        },
                        aria: { expanded: "false", controls: "obs_map" }
                      ))
    new_html = render(Components::Button.new(
                        type: :collapse_toggle,
                        target_id: "obs_map",
                        open_text: :form_observations_hide_map.l,
                        closed_text: :form_observations_open_map.l,
                        icon: :globe,
                        class: "map-toggle",
                        data: {
                          map_target: "toggleMapBtn",
                          action: "map#toggleMap form-exif#showFields"
                        },
                        aria: { expanded: "false", controls: "obs_map" }
                      ))

    # Both emit a `<button>` with collapse + Stimulus wiring.
    assert_html(old_html, "button[data-toggle='collapse']" \
                           "[data-target='#obs_map']")
    assert_html(new_html, "button[data-toggle='collapse']" \
                           "[data-target='#obs_map']")
    assert_html(old_html, "button[data-map-target='toggleMapBtn']")
    assert_html(new_html, "button[data-map-target='toggleMapBtn']")
    assert_html(old_html, "button[aria-controls='obs_map']")
    assert_html(new_html, "button[aria-controls='obs_map']")

    # Globe icon present in both.
    assert_html(old_html, "button span.glyphicon-globe")
    assert_html(new_html, "button span.glyphicon-globe")

    # Intentional change: show/hide span class names replaced.
    # Old used .map-show / .map-hide; new uses Bootstrap-driven spans.
    assert_html(old_html, "span.map-show")
    assert_html(old_html, "span.map-hide")
    assert_no_html(new_html, "span.map-show")
    assert_no_html(new_html, "span.map-hide")
    assert_html(new_html, "span.collapse-toggle-open")
    assert_html(new_html, "span.collapse-toggle-closed")
  end
end
