# frozen_string_literal: true

# A Bootstrap `.badge` showing a count of some type of object (an
# observation count, a fungarium-record count, etc.), with a tooltip
# on hover naming what's being counted. `data-tooltip-target="tip"`
# plugs into the single page-level tooltip Stimulus controller (see
# tooltip_controller.js) -- the badge carries no `data-controller`
# attribute, so it can't pick up accidental DOM-adjacency coupling
# the way the clipboard controller's `nextElementSibling` fallback
# does.
class Components::CountBadge < Components::Base
  prop :count, ::Integer
  prop :type, Symbol, default: :observation

  def view_template
    span(class: "badge count-badge", title: tooltip_title,
         data: { tooltip_target: "tip" }) do
      @count.to_s
    end
  end

  private

  def tooltip_title
    :count_badge_tooltip.t(type: @type.t.upcase_first)
  end
end
