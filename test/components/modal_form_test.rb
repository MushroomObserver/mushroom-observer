# frozen_string_literal: true

require("test_helper")

class ModalFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_modal_structure_and_attributes
    html = render_modal(identifier: "test_form", title: "My Form Title")

    # Modal structure
    assert_html(html, ".modal#modal_test_form[data-controller='modal']")
    assert_html(html, ".modal-dialog.modal-lg[role='document']")
    assert_html(html, ".modal-content")

    # Header with title and close button
    assert_html(html, ".modal-header")
    assert_html(html, "h4.modal-title#modal_test_form_header",
                text: "My Form Title")
    assert_html(html, "button.close[data-dismiss='modal']")

    # Body with flash div
    assert_html(html, ".modal-body#modal_test_form_body")
    assert_html(html, "#modal_test_form_flash")

    # Data and ARIA attributes
    assert_html(html, ".modal[data-modal-user-value='#{@user.id}']")
    assert_html(
      html,
      ".modal[data-action='section-update:updated@window->modal#remove']"
    )
    assert_html(html, ".modal[role='dialog']")
    assert_html(html, ".modal[aria-labelledby='modal_test_form_header']")
  end

  def test_renders_form_component_from_model
    sequence = sequences(:local_sequence)
    obs = sequence.observation

    html = render(Components::ModalForm.new(
                    identifier: "sequence_#{sequence.id}",
                    title: "Edit Sequence",
                    user: @user,
                    model: sequence,
                    observation: obs
                  ))

    # Should render SequenceForm inside the modal body
    assert_html(html, ".modal-body form")
    assert_html(html, "textarea[name='sequence[locus]']")
  end

  private

  def render_modal(identifier:, title:)
    render(Components::ModalForm.new(
             identifier: identifier,
             title: title,
             user: @user
           ))
  end
end
