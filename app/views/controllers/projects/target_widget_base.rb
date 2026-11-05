# frozen_string_literal: true

# Shared base for the inline forms that add target names, target
# locations, or members to a Project (Pattern B / Superform).
#
# The DOM id stays distinct per subclass (turbo-stream wrappers
# replace by id).
class Views::Controllers::Projects::TargetWidgetBase < Components::ApplicationForm
  prop :project, ::Project

  # Optional positional model arg is accepted for ModalForm
  # compatibility (ignored) — see Pattern B in
  # .claude/rules/phlex_reference.md.
  def initialize(_model = nil, project:, **attrs)
    super(form_object, project: project, id: dom_id, turbo: true, **attrs)
  end

  def around_template
    @attributes[:class] = "mb-3 project-target-widget"
    super
  end

  def view_template
    div(class: "mt-3") do
      super do
        autocompleter_field(
          field_name,
          type: autocompleter_type,
          textarea: true,
          label: label_key,
          wrap_class: "d-inline-block align-middle",
          cols: 60
        )
        submit(submit_key.l, class: "d-inline-block align-middle ml-3")
      end
    end
  end

  # Subclasses must implement: dom_id, form_object, field_name,
  # autocompleter_type, label_key, submit_key, form_action.
end
