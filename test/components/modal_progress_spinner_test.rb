# frozen_string_literal: true

require("test_helper")

class ModalProgressSpinnerTest < ComponentTestCase
  def test_renders_non_dismissible_modal_with_spinner
    html = render(Components::ModalProgressSpinner.new)

    # Modal structure with non-dismissible settings
    assert_html(html, "#modal_progress_spinner.modal",
                attribute: { "data-controller": "modal" })
    assert_html(html, "#modal_progress_spinner",
                attribute: { "data-keyboard": "false" })
    assert_html(html, "#modal_progress_spinner",
                attribute: { "data-backdrop": "static" })

    # Caption and spinner elements
    assert_html(html, "#modal_progress_spinner_caption")
    assert_html(html, ".spinner-right.mx-2")

    # Listens for section update to auto-hide
    assert_html(html,
                "[data-action*='section-update:updated@window->modal#hide']")
  end
end
