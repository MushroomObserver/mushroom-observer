# frozen_string_literal: true

# `<span>` with a context-help tooltip — `data-tooltip-target="tip"`
# marks the element as the tooltip Stimulus controller's target, which
# activates Bootstrap's tooltip plugin; that plugin then displays the
# `title=` attribute on hover. Used for inline label-decorating glyphs
# (the `?` next to a filter header, etc.).
#
# @example
#   render(Components::Help::Tooltip.new(label: "(?)",
#                                        title: "Click for explanation"))
class Components::Help::Tooltip < Components::Base
  prop :label, String
  prop :title, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    span(title: @title,
         **mix({ class: "context-help",
                 data: { tooltip_target: "tip" } }, @attributes)) do
      plain(@label)
    end
  end
end
