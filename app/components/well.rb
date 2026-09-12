# frozen_string_literal: true

# Renders a bordered, slim-padded box -- `<div class="well">` by
# default, or any other tag via `element:`. Bootstrap 3's `.well` had
# no BS4 successor; this is MO's minimal replacement (no size
# variants, no background, just padding/border/margin -- see
# `mo/_help_tooltips.scss`). Callers supply their semantic classes
# (`.help-block`, `.position-relative`, etc.) via `class:`.
#
# @example
#   Well(class: "help-block position-relative") { plain("Some help text") }
class Components::Well < Components::Base
  prop :element, Symbol, default: :div
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    send(@element,
         class: class_names("well", @attributes[:class]),
         **@attributes.except(:class),
         &block)
  end
end
