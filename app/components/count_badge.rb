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
  # :outline -- lighter-weight `.badge-outline` styling (see
  # _links_buttons_alerts.scss) for a count that shouldn't read as
  # loudly as the solid default.
  prop :variant, _Union(:solid, :outline), default: :solid
  # Catch-all for class:, data:, and any other HTML attrs -- matches
  # Components::ContentPadded/Table's pattern.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    span(**mix({ class: badge_class, title: tooltip_title,
                 data: { tooltip_target: "tip" } }, @attributes)) do
      @count.to_s
    end
  end

  private

  def badge_class
    return "badge count-badge" unless @variant == :outline

    "badge count-badge badge-outline"
  end

  def tooltip_title
    :count_badge_tooltip.t(type: @type.t.upcase_first)
  end
end
