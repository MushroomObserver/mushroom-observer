# frozen_string_literal: true

module Components
  # Wraps content in Bootstrap's `.navbar-text` styling — the small
  # inline label/link pattern reused across the top nav, the index
  # pagination bar, and the sort dropdown (`SEARCH.l`, `PAGE.l`,
  # `by_letter.l`, `sort_by_header.l`, the anonymous-user login
  # reminder, etc). Element defaults to `<div>`; pass `element:` for
  # the `<li>`/`<strong>` shapes those callers need.
  #
  # Also holds `LINK_CLASSES` and `FORM_CLASS` — plain string/array
  # constants (not renderable shapes) for two other `navbar-*`
  # patterns that recur across the same files but don't share one
  # fixed DOM shape: `.navbar-link` icon-buttons (sometimes a raw
  # `<a>`, sometimes routed through `Link(type: :icon, ...)`) and
  # `.navbar-form` (sometimes a real `<form>` tag, sometimes a plain
  # `<div>` wrapper, sometimes just a `wrapper_class:` string handed
  # to another component like `Dropdown`). A single Phlex tag-emitting
  # component can't cover all three shapes, so callers compose these
  # constants with `class_names` instead.
  #
  # BS4 drops `.navbar-form` entirely and renames `.navbar-right` /
  # `.navbar-left` to margin-auto utilities — every caller that
  # references these constants (instead of retyping the raw strings)
  # gets that swap in one place.
  #
  # @example Default <div> wrapper
  #   Navbar(class: "mx-0") { plain(:PAGE.l) }
  #
  # @example <li> wrapper
  #   Navbar(element: :li, class: "mx-0 hidden-xs") { plain("Sort by:") }
  #
  # @example The class-string constants
  #   a(href: url, class: class_names(Components::Navbar::LINK_CLASSES,
  #                                   "navbar-left"))
  #   form(class: class_names(Components::Navbar::FORM_CLASS, "px-0"))
  class Navbar < Base
    LINK_CLASSES = %w[navbar-link btn btn-lg px-0].freeze
    FORM_CLASS = "navbar-form"

    prop :element, Symbol, default: :div
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      send(@element, **navbar_text_attributes, &block)
    end

    private

    def navbar_text_attributes
      {
        class: class_names("navbar-text", @attributes[:class]),
        **@attributes.except(:class)
      }
    end
  end
end
