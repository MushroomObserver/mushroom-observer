# frozen_string_literal: true

require("test_helper")

class ModalConfirmTest < ComponentTestCase
  def test_modal_structure_and_elements
    html = render(Components::ModalConfirm.new)

    # Modal root: confirm-modal Stimulus controller (NOT the default
    # `modal`), aria-labelledby pointing at the in-body title.
    assert_html(html, "#mo_confirm.modal[data-controller='confirm-modal']")
    assert_html(html, "#mo_confirm[aria-labelledby='mo_confirm_title']")

    # Headerless: no `.modal-header` div at all — the title lives in
    # the body so the Stimulus controller can mutate its text without
    # also having to track a header element.
    assert_no_html(html, "#mo_confirm .modal-header")

    # Title lives INSIDE .modal-body, with .py-4 extra padding.
    assert_html(html,
                ".modal-body.py-4 > #mo_confirm_title.modal-title" \
                "[data-confirm-modal-target='title']",
                text: :are_you_sure.l)

    # Message paragraph (initially empty). The Stimulus controller
    # fills its textContent with the element's `data-turbo-confirm`
    # value when the modal opens — previously the message was passed
    # to `show(message, element)` but never assigned anywhere, so the
    # modal always read just "Are you sure?". Catching that regression
    # here keeps the target wiring tight.
    assert_html(html, "p[data-confirm-modal-target='message']")

    # Cancel button in .modal-footer.
    assert_html(html,
                ".modal-footer > button[data-action='confirm-modal#cancel']",
                text: :CANCEL.l)

    # Confirm button in .modal-footer with the Stimulus target the
    # controller mutates to wire up the actual submit action.
    assert_html(html,
                ".modal-footer > button[data-action='confirm-modal#confirm']" \
                "[data-confirm-modal-target='confirmButton']",
                text: :OK.l)
  end
end
