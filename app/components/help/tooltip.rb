# frozen_string_literal: true

# `<span>` with a context-help tooltip — MO's own
# `data-trigger="tooltip"` (read by `tooltip_controller.js`) displays
# the `title=` attribute on hover. Deliberately not
# `data-toggle="tooltip"`: `data-toggle` is the attribute Bootstrap's
# own plugins key off of, so a distinct name lets an element carry
# both a Bootstrap trigger and a tooltip at once.
# Used for inline label-decorating glyphs (the `?` next to a filter
# header, etc.).
#
# @example
#   render(Components::Help::Tooltip.new(label: "(?)",
#                                        title: "Click for explanation"))
class Components::Help::Tooltip < Components::Base
  prop :label, String
  prop :title, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :data, Hash, default: -> { {} }

  def view_template
    span(class: class_names("context-help", @extra_class),
         title: @title,
         data: { trigger: "tooltip" }.merge(@data)) do
      plain(@label)
    end
  end
end
