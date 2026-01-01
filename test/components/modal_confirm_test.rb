# frozen_string_literal: true

require("test_helper")

class ModalConfirmTest < ComponentTestCase
  def test_renders_modal_structure
    html = render(Components::ModalConfirm.new)

    assert_html(html, "#mo_confirm.modal[data-controller='confirm-modal']")
  end

  def test_renders_title_with_target
    html = render(Components::ModalConfirm.new)

    assert_html(
      html,
      "#mo_confirm_title[data-confirm-modal-target='title']",
      text: "Are you sure?"
    )
  end

  def test_renders_cancel_button
    html = render(Components::ModalConfirm.new)

    assert_html(
      html,
      "button[data-action='confirm-modal#cancel']",
      text: "Cancel"
    )
  end

  def test_renders_confirm_button_with_target
    html = render(Components::ModalConfirm.new)

    assert_html(
      html,
      "button[data-action='confirm-modal#confirm']" \
      "[data-confirm-modal-target='confirmButton']",
      text: "OK"
    )
  end
end
