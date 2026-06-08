# frozen_string_literal: true

# `<span>` with a context-help tooltip — Bootstrap's
# `data-toggle="tooltip"` displays the `title=` attribute on hover.
# Used for inline label-decorating glyphs (the `?` next to a filter
# header, etc.).
#
# Replaces the `help_tooltip` helper from `panel_helper.rb`.
#
# @example
#   render(Components::HelpTooltip.new("(?)",
#                                      title: "Click for explanation"))
class Components::HelpTooltip < Components::Base
  prop :label, String
  prop :title, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :data, Hash, default: -> { {} }

  def view_template
    span(class: class_names("context-help", @extra_class),
         title: @title,
         data: { toggle: "tooltip" }.merge(@data)) do
      plain(@label)
    end
  end
end
