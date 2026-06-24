# frozen_string_literal: true

# Question-icon collapse trigger — thin wrapper over
# `Components::Link::CollapseToggle` that fixes the icon and the
# `info-collapse-trigger` class so callers don't repeat them.
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
    render(::Components::Link::CollapseToggle.new(
             target_id: @target_id,
             class: class_names("info-collapse-trigger", @extra_class)
           )) do
      render(::Components::Icon.new(type: :question))
    end
  end
end
