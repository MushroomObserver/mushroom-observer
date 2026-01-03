# frozen_string_literal: true

# Collapse info trigger component - clickable icon that toggles collapse
#
# @example
#   CollapseInfoTrigger(id: "help_text_1")
#   CollapseInfoTrigger(id: "help_text_2", class: "custom-trigger")
class Components::CollapseInfoTrigger < Components::Base
  prop :target_id, String
  prop :extra_class, String, default: ""

  def view_template
    a(
      href: "##{@target_id}",
      class: class_names("info-collapse-trigger", @extra_class),
      role: "button",
      data: { toggle: "collapse" },
      aria: { expanded: "false", controls: @target_id }
    ) do
      span(class: "glyphicon glyphicon-question-sign link-icon")
    end
  end
end
