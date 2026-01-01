# frozen_string_literal: true

require("test_helper")

class ModalProgressSpinnerTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_modal_structure
    html = render(Components::ModalProgressSpinner.new)

    assert_includes(html, 'id="mo_ajax_progress"')
    assert_includes(html, 'class="modal"')
    assert_includes(html, 'data-controller="modal"')
  end

  def test_renders_non_dismissible_modal
    html = render(Components::ModalProgressSpinner.new)

    assert_includes(html, 'data-keyboard="false"')
    assert_includes(html, 'data-backdrop="static"')
  end

  def test_renders_caption_and_spinner
    html = render(Components::ModalProgressSpinner.new)

    assert_includes(html, 'id="mo_ajax_progress_caption"')
    assert_includes(html, 'class="spinner-right mx-2"')
  end

  def test_listens_for_section_update_event
    html = render(Components::ModalProgressSpinner.new)

    assert_includes(html, "section-update:updated@window->modal#hide")
  end
end
