# frozen_string_literal: true

# Bootstrap accordion where exactly one of the peer collapse divs
# is visible at a time. Callers supply the trigger links (with
# `data-toggle="collapse"`, `data-target="#pane_id"`,
# `data-parent="#accordion_id"`) anywhere on the page — inside a
# pane or elsewhere.
#
# Add as many `with_pane` slots as needed. `id:` is required on each
# pane — callers' `data-target` / `href` must point at it. Pass
# `expanded: true` on the one that starts visible; the rest start
# collapsed. Pass `class:` on a pane for styling specific to that
# pane (e.g. `class: "p-3"` when the accordion sits inside a
# zero-padding parent) -- separate from the `class:` passed to
# `Accordion` itself, which styles the shared inner wrapper.
#
# Bootstrap 4's `collapse.js` (`Collapse#_getParent`) closes sibling
# panes via `[data-toggle="collapse"][data-parent="..."]`, a plain
# attribute selector -- the inner wrapper needs no Bootstrap component
# class for this to work. `border-none`/`bg-none` strip its visual
# chrome (border, background); `margin-bottom: ~20px` on the outer div
# is the default spacing below an accordion instance, e.g. between
# successive rows in `account/api_keys/table.rb`. Pass `class:` (via
# the `attributes:` catch-all) for spacing overrides -- e.g.
# `class: "m-0"`.
#
# @example Inline notes editor in a table row
#   Accordion(id: "notes_#{key.id}") do |accordion|
#     accordion.with_pane(id: "view_notes_#{key.id}_container",
#                         expanded: true) do
#       read_only_notes_and_edit_button(key)
#     end
#     accordion.with_pane(id: "edit_notes_#{key.id}_container") do
#       edit_notes_form(key)
#     end
#   end
#
# @example Inline in an already-padded body -- no extra bottom margin
#   Accordion(id: "external_links_accordion", class: "m-0")
#
# @example Bootstrap's default slide transition instead of the fade
#   Accordion(id: "external_links_accordion", slide: true)
class Components::Accordion < Components::Base
  include Phlex::Slotable

  prop :id, String
  # Every pane fades (via `.fade-not-slide`, see Collapsible) rather
  # than sliding open/closed by default -- pass `slide: true` for
  # Bootstrap's own default slide transition instead.
  prop :slide, _Boolean, default: false
  # Catch-all for class:, data:, aria:, and any other HTML attrs on
  # the inner wrapper -- matches Icon/Collapsible's pattern.
  prop :attributes, _Hash(Symbol, _Any?), :**

  slot :pane, lambda { |id:, expanded: false, class: nil, &content|
    Collapsible(
      id: id, expanded: expanded,
      class: class_names((@slide ? nil : "fade-not-slide"), grab(class:))
    ) { content&.call }
  }, collection: true

  def view_template
    div(class: "border-none mb-0", id: @id) do
      div(class: inner_class, **@attributes.except(:class)) do
        pane_slots.each { |pane| render(pane) } if pane_slots?
      end
    end
  end

  private

  def inner_class
    class_names("border-none bg-none", @attributes[:class])
  end
end
