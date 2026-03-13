# frozen_string_literal: true

require("test_helper")

class ModalConfirmTest < ComponentTestCase
  def test_modal_structure_and_elements
    html = render(Components::ModalConfirm.new)

    # Modal structure
    assert_html(html, "#mo_confirm.modal[data-controller='confirm-modal']")

    # Title with target
    assert_html(
      html,
      "#mo_confirm_title[data-confirm-modal-target='title']",
      text: "Are you sure?"
    )

    # Cancel button
    assert_html(
      html,
      "button[data-action='confirm-modal#cancel']",
      text: "Cancel"
    )

    # Confirm button with target
    assert_html(
      html,
      "button[data-action='confirm-modal#confirm']" \
      "[data-confirm-modal-target='confirmButton']",
      text: "OK"
    )
  end
end
