# frozen_string_literal: true

# Wraps content in Bootstrap's `.navbar-text` styling — the small
# inline label/link pattern reused across the top nav, the index
# pagination bar, and the sort dropdown (`SEARCH.l`, `PAGE.l`,
# `by_letter.l`, `sort_by_header.l`, the anonymous-user login
# reminder, etc). This is inline content sitting *inside* an already-
# real `<nav>` landmark declared elsewhere (or inside a `<ul>`/
# `<form>` that dictates its own tag) — never a landmark itself, and
# not a `.navbar` at all despite the shared name prefix (see
# `Components::Navbar` for the actual landmark wrapper). Element
# defaults to `<div>`; pass `element:` for the `<li>`/`<strong>`
# shapes those callers need. Stays `<div>`/`<span>` under BS4 too
# (`.navbar-text`'s canonical BS4 shape is `<span>`, still non-
# landmark).
#
# No Kit sugar - nested one level deeper than `Components`, so this
# is reached via `render(Components::Navbar::Text.new(...))`, not a
# bare `Navbar(...)` call.
#
# @example Default <div class="navbar-text"> wrapper
#   render(Components::Navbar::Text.new(class: "mx-0")) { plain(:PAGE.l) }
#
# @example <li class="navbar-text"> wrapper
#   render(Components::Navbar::Text.new(element: :li,
#                                       class: "mx-0 hidden-xs")) do
#     plain("Sort by:")
#   end
class Components::Navbar::Text < Components::Base
  prop :element, _Nilable(Symbol), default: nil
  prop :attributes, _Hash(Symbol, _Any), :**

  def view_template(&block)
    send(@element || :div, **computed_attributes, &block)
  end

  private

  def computed_attributes
    {
      class: class_names("navbar-text", @attributes[:class]),
      **@attributes.except(:class)
    }
  end
end
