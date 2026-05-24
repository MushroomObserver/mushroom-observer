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
    # Stub a Views::Controllers::Projects::Members::Form class so we
    # can test that a namespaced controller_path resolves to it,
    # even though the model class (`ProjectMember`) wouldn't on its
    # own (`.demodulize` strips the namespace; we need the path).
    stub_const("Views::Controllers::Projects", Module.new)
    stub_const("Views::Controllers::Projects::Members", Module.new)
    klass = Class.new
    Views::Controllers::Projects::Members.const_set(:Form, klass)

    resolved = Components::ModalTurboForm.form_component_class_for(
      ProjectMember.new, controller_path: "projects/members"
    )
    assert_equal(klass, resolved)
  ensure
    Views::Controllers::Projects::Members.send(:remove_const, :Form)
    Views::Controllers.send(:remove_const, :Projects)
  end

  def test_form_component_class_for_falls_back_to_model_name_derivation
    # No controller_path given. Comment model -> Comments::Form.
    resolved = Components::ModalTurboForm.form_component_class_for(
      Comment.new
    )
    assert_equal(Views::Controllers::Comments::Form, resolved)
  end

  def test_form_component_class_for_falls_back_to_legacy_components
    # No view file exists for Project (yet); should fall back to the
    # legacy Components::ProjectForm.
    resolved = Components::ModalTurboForm.form_component_class_for(
      Project.new
    )
    assert_equal(Components::ProjectForm, resolved)
  end

  private

  def stub_const(qualified_name, value)
    parts = qualified_name.split("::")
    parent = parts[0..-2].inject(Object) do |mod, name|
      if mod.const_defined?(name)
        mod.const_get(name)
      else
        mod.const_set(name,
                      Module.new)
      end
    end
    parent.const_set(parts[-1], value) unless parent.const_defined?(parts[-1])
  end

  def render_modal(identifier:, title:)
    render(Components::ModalTurboForm.new(
             identifier: identifier,
             title: title,
             user: @user
           ))
  end
end
