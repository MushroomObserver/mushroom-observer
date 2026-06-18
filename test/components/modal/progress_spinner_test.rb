# frozen_string_literal: true

require("test_helper")

class ModalProgressSpinnerTest < ComponentTestCase
  def test_renders_non_dismissible_modal_with_spinner
    html = render(Components::Modal::ProgressSpinner.new)

    # Modal root: default `modal` Stimulus controller, non-dismissible
    # settings (no keyboard ESC, static backdrop = no click-outside).
    assert_html(html, "#modal_progress_spinner.modal" \
                      "[data-controller='modal']" \
                      "[data-keyboard='false']" \
                      "[data-backdrop='static']")

    # Listens for section-update to auto-hide programmatically.
    assert_html(html,
                "#modal_progress_spinner" \
                "[data-action*='section-update:updated@window->modal#hide']")

    # Small dialog variant.
    assert_html(html, ".modal-dialog.modal-sm")

    # Headerless + footerless: just a centered body with caption + spinner.
    assert_no_html(html, "#modal_progress_spinner .modal-header")
    assert_no_html(html, "#modal_progress_spinner .modal-footer")

    # aria-labelledby points to the caption inside the body (the
    # caption text is what announces the in-progress operation).
    assert_html(html,
                "#modal_progress_spinner" \
                "[aria-labelledby='modal_progress_spinner_caption']")

    # Body: text-center class + caption span + spinner span.
    assert_html(html,
                "#modal_progress_spinner_body.modal-body.text-center " \
                "> #modal_progress_spinner_caption")
    assert_html(html,
                "#modal_progress_spinner_body > span.spinner-right.mx-2")
  end
end
