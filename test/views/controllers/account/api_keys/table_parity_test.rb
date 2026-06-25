# frozen_string_literal: true

require("test_helper")

# Pre-refactor edit-notes trigger in `Table`.
# Old: `Components::Button` (a `<button>`).
# New: `Link::CollapseToggle` (an `<a role="button">`).
class OldViewNotes < Components::Base
  def view_template
    render(::Components::Button.new(
             name: :EDIT.l, icon: :edit,
             class: "collapsed",
             aria: { expanded: "false",
                     controls: "edit_notes_42_container" },
             data: { toggle: "collapse",
                     role: "edit_api_key",
                     target: "#edit_notes_42_container",
                     parent: "#notes_42" }
           ))
  end
end

# Pre-refactor "+ Add Key" trigger in `Table`.
# Old: `Components::Button` with `type: :get` (an `<a>`).
# New: `Link::CollapseToggle` (also an `<a>`).
class OldNewButton < Components::Base
  def view_template
    render(::Components::Button.new(
             type: :get, id: "new_key_button",
             name: :account_api_keys_create_button.l,
             target: new_account_api_key_path,
             class: "collapsed",
             aria: { expanded: "false",
                     controls: "new_key_form_container" },
             data: { toggle: "collapse",
                     target: "#new_key_form_container",
                     parent: "#new_key_row" }
           ))
  end
end

# Documents the migration of `render_view_notes_button` and
# `render_new_button` in `Views::Controllers::Account::APIKeys::Table`
# to `Link::CollapseToggle`.
module Views::Controllers::Account::APIKeys
  class TableParityTest < ComponentTestCase
    # --- Edit-notes trigger ---

    # Old rendered a `<button>`; new renders `<a role="button">`.
    # The icon gains a tooltip title (intentional — improves
    # accessibility). The text label moves from `span.sr-only`
    # to `span.collapse-toggle-closed`.
    def test_edit_link_preserves_behavioral_wiring
      old_html = render(OldViewNotes.new)
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "edit_notes_42_container",
                          icon: :edit,
                          closed_text: " #{:EDIT.l}",
                          button: :default,
                          data: { role: "edit_api_key",
                                  parent: "#notes_42" }
                        ))

      # Collapse wiring + ARIA in both.
      assert_html(old_html,
                  "button[data-toggle='collapse']" \
                  "[data-role='edit_api_key']" \
                  "[aria-controls='edit_notes_42_container']" \
                  "[aria-expanded='false']")
      assert_html(new_html,
                  "a[data-toggle='collapse']" \
                  "[data-role='edit_api_key']" \
                  "[aria-controls='edit_notes_42_container']" \
                  "[aria-expanded='false']")

      # Parent constraint preserved in both.
      assert_html(old_html, "button[data-parent='#notes_42']")
      assert_html(new_html, "a[data-parent='#notes_42']")

      # Edit icon present in both (title added intentionally in new).
      assert_html(old_html, "span.glyphicon-edit")
      assert_html(new_html, "span.glyphicon-edit")

      # Intentional changes: element type, collapse pointer, text span.
      assert_html(old_html, "button[data-target='#edit_notes_42_container']")
      assert_html(new_html,
                  "a[href='#edit_notes_42_container'][role='button']")
      assert_no_html(old_html, "span.collapse-toggle-closed")
      assert_html(new_html, "span.collapse-toggle-closed")
    end

    # --- "+ Add Key" trigger ---

    # Both old (`Button::Get`) and new (`Link::CollapseToggle`) render
    # `<a>`. Old has plain text; new wraps text in
    # `span.collapse-toggle-closed` and adds `role="button"`.
    def test_new_button_preserves_behavioral_wiring
      api_key_path = routes.new_account_api_key_path
      old_html = render(OldNewButton.new)
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "new_key_form_container",
                          fallback_href: api_key_path,
                          closed_text: :account_api_keys_create_button.l,
                          button: :default,
                          id: "new_key_button",
                          data: { parent: "#new_key_row" }
                        ))

      # Both render `<a>` pointing to the new-key path.
      assert_html(old_html,
                  "a#new_key_button" \
                  "[href='#{api_key_path}']" \
                  "[data-toggle='collapse']" \
                  "[data-target='#new_key_form_container']" \
                  "[data-parent='#new_key_row']" \
                  "[aria-controls='new_key_form_container']" \
                  "[aria-expanded='false']")
      assert_html(new_html,
                  "a#new_key_button" \
                  "[href='#{api_key_path}']" \
                  "[data-toggle='collapse']" \
                  "[data-target='#new_key_form_container']" \
                  "[data-parent='#new_key_row']" \
                  "[aria-controls='new_key_form_container']" \
                  "[aria-expanded='false']")

      # Intentional changes: new adds `role="button"` and wraps text.
      assert_no_html(old_html, "a[role='button']")
      assert_html(new_html, "a[role='button']")
      assert_no_html(old_html, "span.collapse-toggle-closed")
      assert_html(new_html, "span.collapse-toggle-closed")
    end
  end
end
