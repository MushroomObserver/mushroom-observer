# frozen_string_literal: true

# Collapse info trigger component - clickable icon that toggles collapse
#
# @example
#   render(Components::Help::CollapseInfoTrigger.new(target_id: "help_text_1"))
#   render(Components::Help::CollapseInfoTrigger.new(
#            target_id: "help_text_2", extra_class: "custom-trigger"
#          ))
class Components::Help::CollapseInfoTrigger < Components::Base
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
      render(::Components::Icon.new(type: :question))
    end
  end
end
