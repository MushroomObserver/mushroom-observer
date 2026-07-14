# frozen_string_literal: true

# Renders a Bootstrap grid row -- `<div class="row">` by default, or any
# other tag via `element:` (several call sites need `<ul class="row
# list-unstyled">`). Centralizes the one hardcoded `"row"` string that
# was previously duplicated across ~76 call sites, each concatenating
# it with whatever extra utility/alignment classes that spot needed.
#
# `.row` itself is untouched Bootstrap (MO never redefines the bare
# selector) -- this component doesn't map or interpret anything the way
# Components::Container does for width; it's just a stable, reusable
# spelling of "this is a Bootstrap row" plus generic HTML-attrs merging,
# following the same prop pattern as Components::Container/Collapsible/
# Navbar.
#
# @example Basic (a <div>)
#   Row { div(class: "col-sm-6") { ... } }
#
# @example With extra classes/attrs
#   Row(class: "mt-3 align-items-center") { ... }
#
# @example As a <ul> (list-reset rows)
#   Row(element: :ul, class: "list-unstyled mt-3") { ... }
class Components::Row < Components::Base
  prop :element, Symbol, default: :div
  # Catch-all for class:, id:, data:, and any other HTML attrs --
  # matches Components::Container/Collapsible/Navbar's pattern.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    send(@element,
         class: class_names("row", @attributes[:class]),
         **@attributes.except(:class),
         &block)
  end
end
