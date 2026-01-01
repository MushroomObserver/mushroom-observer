# frozen_string_literal: true

require("test_helper")

class ModalFormTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_modal_structure
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "Test Modal",
                    user: user
                  ))

    assert_html(html, ".modal#modal_test_form")
    assert_html(html, ".modal-dialog.modal-lg")
    assert_html(html, ".modal-content")
  end

  def test_renders_header_with_title
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "My Form Title",
                    user: user
                  ))

    assert_html(html, ".modal-header")
    assert_html(html, "h4.modal-title#modal_test_form_header",
                text: "My Form Title")
  end

  def test_renders_close_button
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "Test",
                    user: user
                  ))

    assert_html(html, "button.close[data-dismiss='modal']")
    assert_html(html, "button.close span", text: "×")
  end

  def test_renders_body_with_flash_div
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "Test",
                    user: user
                  ))

    assert_html(html, ".modal-body#modal_test_form_body")
    assert_html(html, "#modal_test_form_flash")
  end

  def test_renders_form_content_slot
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "Test",
                    user: user
                  )) do |modal|
      modal.with_form_content do
        view_context.tag.form(id: "my_form") do
          view_context.tag.input(type: "text", name: "field")
        end
      end
    end

    assert_html(html, ".modal-body form#my_form")
    assert_html(html, ".modal-body input[name='field']")
  end

  def test_modal_data_attributes
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "test_form",
                    title: "Test",
                    user: user
                  ))

    assert_html(html, ".modal[data-controller='modal']")
    assert_html(html, ".modal[data-modal-user-value='#{user.id}']")
    assert_html(
      html,
      ".modal[data-action='section-update:updated@window->modal#remove']"
    )
  end

  def test_aria_attributes
    user = users(:rolf)

    html = render(Components::ModalForm.new(
                    identifier: "aria_test",
                    title: "Test",
                    user: user
                  ))

    assert_html(html, ".modal[role='dialog']")
    assert_html(html, ".modal[aria-labelledby='modal_aria_test_header']")
    assert_html(html, ".modal-dialog[role='document']")
  end
end
