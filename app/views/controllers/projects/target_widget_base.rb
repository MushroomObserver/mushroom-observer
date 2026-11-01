# frozen_string_literal: true

# Shared base for the two inline forms that add target names or target
# locations to a Project (Pattern B / Superform). Subclasses fill in
# the few pieces that vary per type via the abstract methods listed
# below; the rendering shape is otherwise identical.
#
# The DOM id stays distinct per subclass (turbo-stream wrappers
# replace by id), and `_form_elements.scss` targets those ids for the
# textarea-width override. Both subclasses also share the
# `project-target-widget` class.
class Views::Controllers::Projects::TargetWidgetBase < Components::ApplicationForm
  prop :project, ::Project

  # Optional positional model arg is accepted for ModalForm
  # compatibility (ignored) — see Pattern B in
  # .claude/rules/phlex_reference.md.
  def initialize(_model = nil, project:, **attrs)
    super(form_object, project: project, id: dom_id, turbo: true, **attrs)
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
        label: label_key
      )
      submit(submit_key.l, class: "ml-2 mt-2")
    end
  end

  # Subclasses must implement: dom_id, form_object, field_name,
  # autocompleter_type, label_key, submit_key, form_action.
end
