# frozen_string_literal: true

# Shared base for the two inline forms that add target names or target
# locations to a Project (Pattern B / Superform). Subclasses fill in
# the few pieces that vary per type via the abstract methods listed
# below; the rendering shape is otherwise identical.
#
# The DOM id stays distinct per subclass (turbo-stream wrappers
# replace by id), but both subclasses share the
# `project-target-widget` class so the textarea-width CSS rule in
# `_form_elements.scss` applies to both.
class Components::ProjectTargetWidgetBase < Components::ApplicationForm
  # Optional positional model arg is accepted for ModalForm
  # compatibility (ignored) — see Pattern B in
  # .claude/phlex_style_guide.md.
  def initialize(_model = nil, project:, **)
    @project = project
    super(form_object, id: dom_id, local: false, **)
  end

  def around_template
    @attributes[:class] = "form-inline mb-3 project-target-widget"
    super
  end

  def view_template
    super do
      autocompleter_field(
        field_name,
        type: autocompleter_type,
        textarea: true,
        label: label_key.l
      )
      submit(submit_key.l, class: "ml-2 mt-2")
    end
  end

  # Subclasses must implement: dom_id, form_object, field_name,
  # autocompleter_type, label_key, submit_key, form_action.
end
