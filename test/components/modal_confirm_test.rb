# frozen_string_literal: true

require("test_helper")

class ModalConfirmTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_modal_structure
    html = render(Components::ModalConfirm.new)

    assert_includes(html, 'id="mo_confirm"')
    assert_includes(html, 'class="modal"')
    assert_includes(html, 'data-controller="confirm-modal"')
  end

  def test_renders_title_with_target
    html = render(Components::ModalConfirm.new)

    assert_includes(html, 'id="mo_confirm_title"')
    assert_includes(html, 'data-confirm-modal-target="title"')
    assert_includes(html, "Are you sure?")
  end

  def test_renders_cancel_button
    html = render(Components::ModalConfirm.new)

    assert_includes(html, 'data-action="confirm-modal#cancel"')
    assert_includes(html, "Cancel")
  end

  def test_renders_confirm_button_with_target
    html = render(Components::ModalConfirm.new)

    assert_includes(html, 'data-action="confirm-modal#confirm"')
    assert_includes(html, 'data-confirm-modal-target="confirmButton"')
    assert_includes(html, "OK")
  end
end
