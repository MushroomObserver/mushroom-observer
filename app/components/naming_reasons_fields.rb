# frozen_string_literal: true

# Renders naming reason checkboxes and collapsible textareas.
# Used in naming form to allow users to provide notes for each reason.
#
# @param reasons [Hash] the naming reasons from Naming#init_reasons
# @param naming_ns [Superform::Namespace] the naming namespace
class Components::NamingReasonsFields < Components::Base
  prop :reasons, Hash
  prop :naming_ns, _Any

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
               label: reason.label.t,
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
    # Bootstrap 3: "collapse" when hidden, "collapse in" when visible
    collapse_class = reason.used? ? "collapse in" : "collapse"

    div(id: "naming_reasons_#{reason.num}_notes",
        class: class_names("form-group mb-3", collapse_class),
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
