# frozen_string_literal: true

# Renders naming reason checkboxes and collapsible textareas. Used
# inside `Views::Controllers::Observations::Namings::Fields` to let
# users provide notes for each reason.
#
# @param reasons [Hash] the naming reasons from Naming#init_reasons
# @param naming_ns [Superform::Namespace] the naming namespace
class Views::Controllers::Observations::Namings::ReasonsFields < Views::Base
  prop :reasons, _Hash(Integer, ::Naming::Reason)
  # Either a `Superform::Namespace` (when the parent `Fields` view
  # wraps in `namespace(:naming)`) or the form itself (when
  # `add_namespace: false` skips the wrap and passes `@form`
  # directly — `Superform::Rails::Form` delegates `#field` /
  # `#namespace` to its root namespace). Duck-typed to keep test
  # stubs that only implement those two methods working.
  prop :naming_ns, _Interface(:field, :namespace)

  def view_template
    @naming_ns.namespace(:reasons) do |reasons_ns|
      @reasons.values.sort_by(&:order).each do |reason|
        render_reason_container(reasons_ns, reason)
      end
    end
  end

  private

  def render_reason_container(reasons_ns, reason)
    reasons_ns.namespace(reason.num.to_s) do |reason_ns|
      div(class: "naming-reason-container", data: container_data) do
        render_checkbox(reason_ns, reason)
        render_textarea(reason_ns, reason)
      end
    end
  end

  def container_data
    {
      controller: "naming-reason",
      action: "$shown.bs.collapse->naming-reason#focusInput " \
              "$hidden.bs.collapse->naming-reason#clearInput"
    }
  end

  def render_checkbox(reason_ns, reason)
    render(reason_ns.field(:check).checkbox(
             wrapper_options: {
               label: reason.label,
               label_data: checkbox_label_data(reason),
               label_aria: checkbox_label_aria(reason)
             },
             checked: reason.used?,
             id: checkbox_id(reason)
           ))
  end

  def checkbox_id(reason)
    "naming_reasons_#{reason.num}_check"
  end

  def checkbox_label_data(reason)
    {
      toggle: "collapse",
      target: "#naming_reasons_#{reason.num}_notes"
    }
  end

  def checkbox_label_aria(reason)
    {
      expanded: reason.used?.to_s,
      controls: "naming_reasons_#{reason.num}_notes"
    }
  end

  def render_textarea(reason_ns, reason)
    Collapsible(id: "naming_reasons_#{reason.num}_notes",
                expanded: reason.used?,
                class: "form-group mb-3",
                data: { naming_reason_target: "collapse" }) do
      render(reason_ns.field(:notes).textarea(
               wrapper_options: { label: false },
               rows: 3,
               value: reason.notes,
               data: { naming_reason_target: "input" }
             ))
    end
  end
end
