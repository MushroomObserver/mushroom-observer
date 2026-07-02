# frozen_string_literal: true

# Bootstrap accordion where exactly one of the peer collapse divs
# is visible at a time. Callers supply the trigger links (with
# `data-toggle="collapse"`, `data-target="#pane_id"`,
# `data-parent="#accordion_id"`) anywhere on the page — inside the
# slots or elsewhere.
#
# @example Inline notes editor in a table row
#   render(Components::Accordion.new(
#     id: "notes_#{key.id}",
#     view_id: "view_notes_#{key.id}_container",
#     edit_id: "edit_notes_#{key.id}_container"
#   )) do |accordion|
#     accordion.with_view { read_only_notes_and_edit_button(key) }
#     accordion.with_edit { edit_notes_form(key) }
#   end
class Components::Accordion < Components::Base
  include Phlex::Slotable

  prop :id, String
  prop :view_id, String
  prop :edit_id, String

  slot :view
  slot :edit

  def view_template
    div(class: "border-none mb-0", id: @id) do
      div(class: "panel border-none bg-none") do
        render(::Components::CollapseDiv.new(
                 id: @view_id, expanded: true,
                 html_class: "no-transition"
               )) { render(view_slot) if view_slot? }
        render(::Components::CollapseDiv.new(
                 id: @edit_id,
                 html_class: "no-transition"
               )) { render(edit_slot) if edit_slot? }
      end
    end
  end
end
