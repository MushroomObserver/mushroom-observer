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
# collapsed.
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
class Components::Accordion < Components::Base
  include Phlex::Slotable

  prop :id, String

  slot :pane, lambda { |id:, expanded: false, &content|
    CollapseDiv(
      id: id, expanded: expanded, html_class: "no-transition"
    ) { content&.call }
  }, collection: true

  def view_template
    div(class: "border-none mb-0", id: @id) do
      div(class: "panel border-none bg-none") do
        pane_slots.each { |pane| render(pane) } if pane_slots?
      end
    end
  end
end
