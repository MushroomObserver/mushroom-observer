# frozen_string_literal: true

require("test_helper")

class ModalTurboFormTest < ComponentTestCase
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

    html = render(Components::ModalTurboForm.new(
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

  # Direct tests of the `form_component_class_for` lookup — covers
  # the three resolution paths (caller's controller_path, model-name
  # derivation, legacy Components fallback).

  def test_form_class_lookup_uses_controller_path_for_namespaced_controllers
    # `Views::Controllers::Account::APIKeys::Form` is the canonical
    # real namespaced-controller view on main (post #4321). The
    # model-only fallback path can't reach it — `APIKey.demodulize`
    # is "APIKey" -> "ApiKeys", which is the wrong namespace.
    # Only the controller_path lookup gets it right.
    resolved = Components::ModalTurboForm.form_component_class_for(
      APIKey.new, controller_path: "account/api_keys"
    )
    assert_equal(Views::Controllers::Account::APIKeys::Form, resolved)
  end

  def test_form_class_lookup_falls_back_to_model_name_derivation
    # No controller_path given. Comment model -> Comments::Form.
    resolved = Components::ModalTurboForm.form_component_class_for(
      Comment.new
    )
    assert_equal(Views::Controllers::Comments::Form, resolved)
  end

  def test_form_class_lookup_falls_back_to_legacy_components
    # No view file exists for Project (yet); should fall back to the
    # legacy Components::ProjectForm.
    resolved = Components::ModalTurboForm.form_component_class_for(
      Project.new
    )
    assert_equal(Components::ProjectForm, resolved)
  end

  private

  def render_modal(identifier:, title:)
    render(Components::ModalTurboForm.new(
             identifier: identifier,
             title: title,
             user: @user
           ))
  end
end
