# frozen_string_literal: true

require("test_helper")

# Pre-refactor cancel button in `Views::Controllers::Account::APIKeys::Form`.
# Old code used `Components::Button` with a block; new code uses
# `Link::CollapseToggle`.
class OldCancelButton < Components::Base
  def view_template
    render(::Components::Button.new(
             aria: { expanded: "true",
                     controls: "test_target" },
             data: { toggle: "collapse",
                     target: "#test_target",
                     parent: "#test_parent" }
           )) do
      render(::Components::Icon.new(
               type: :cancel, title: :CANCEL.l
             ))
    end
  end
end

# Documents the migration of `render_cancel_button` in
# `Views::Controllers::Account::APIKeys::Form` from `Components::Button`
# with block to `Link::CollapseToggle`.
#
# Intentional change: element type `<button>` → `<a role="button">`.
# Icon content, collapse wiring, and parent constraint are preserved.
module Views::Controllers::Account::APIKeys
  class FormParityTest < ComponentTestCase
    def test_cancel_button_preserves_behavioral_wiring
      old_html = render(OldCancelButton.new)
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "test_target",
                          collapsed: false,
                          icon: :cancel,
                          icon_title: :CANCEL.l,
                          button: :default,
                          data: { parent: "#test_parent" }
                        ))

      # Collapse wiring + ARIA in both.
      assert_html(old_html,
                  "button[data-toggle='collapse']" \
                  "[aria-expanded='true']" \
                  "[aria-controls='test_target']")
      assert_html(new_html,
                  "a[data-toggle='collapse']" \
                  "[aria-expanded='true']" \
                  "[aria-controls='test_target']")

      # Parent constraint preserved in both.
      assert_html(old_html, "button[data-parent='#test_parent']")
      assert_html(new_html, "a[data-parent='#test_parent']")

      # Cancel icon subtree is identical in both.
      assert_html(old_html, "span.glyphicon-remove")
      assert_html(new_html, "span.glyphicon-remove")
      assert_html_element_equivalent(old_html, new_html,
                                     selector: "span.glyphicon",
                                     label: "cancel_icon")

      # Intentional change: element type and collapse pointer.
      assert_html(old_html, "button[data-target='#test_target']")
      assert_html(new_html, "a[href='#test_target'][role='button']")
      assert_no_html(new_html, "button")
    end
  end
end
