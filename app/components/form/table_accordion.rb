# frozen_string_literal: true

# Bootstrap 3 accordion-style "swap-in-place" panel used inside a
# table cell (or just below a table) where one of two peer
# `panel-collapse` divs is visible at a time:
#
#   - the `view` slot renders the default-visible pane
#     (e.g. read-only text + an "edit" trigger button)
#   - the `edit` slot renders the hidden pane that takes its place
#     when the trigger fires (e.g. an inline form with a "cancel"
#     button)
#
# Each pane has its own DOM id so caller-supplied triggers (with
# `data-toggle="collapse"`, `data-target="#X"`, `data-parent="#Y"`)
# can toggle between them. The panel itself has no background so it
# blends into striped-table rows.
#
# @example Inline notes editor in a table row
#   render(Components::Form::TableAccordion.new(
#     id: "notes_#{key.id}",
#     view_id: "view_notes_#{key.id}_container",
#     edit_id: "edit_notes_#{key.id}_container"
#   )) do |accordion|
#     accordion.with_view { read_only_notes_and_edit_button(key) }
#     accordion.with_edit { edit_notes_form(key) }
#   end
class Components::Form::TableAccordion < Components::Base
  include Phlex::Slotable

  prop :id, String
  prop :view_id, String
  prop :edit_id, String

  slot :view
  slot :edit

  def view_template
    div(class: "panel-group border-none mb-0", id: @id) do
      div(class: "panel border-none bg-none") do
        render(::Components::CollapseDiv.new(
                 id: @view_id, expanded: true, panel: true,
                 html_class: "no-transition"
               )) { render(view_slot) if view_slot? }
        render(::Components::CollapseDiv.new(
                 id: @edit_id, panel: true,
                 html_class: "no-transition"
               )) { render(edit_slot) if edit_slot? }
      end
    end
  end
end
