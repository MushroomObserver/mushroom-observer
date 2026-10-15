# frozen_string_literal: true

# Question-icon collapse trigger — thin wrapper over
# `Components::Link::CollapseToggle` that fixes the icon and the
# `info-collapse-trigger` class so callers don't repeat them.
class Components::Help::CollapseInfoTrigger < Components::Base
  prop :target_id, String
  prop :extra_class, String, default: ""

  def view_template
    Link(type: :collapse_toggle,
         target_id: @target_id,
         class: class_names("info-collapse-trigger inline-flex-center",
                            @extra_class)) do
      Icon(type: :question, title: :help.ti, center_tooltip: true)
    end
  end
end
