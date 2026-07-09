# frozen_string_literal: true

module Components
  # Wraps content in Bootstrap's `.navbar-text` styling by default — the
  # small inline label/link pattern reused across the top nav, the index
  # pagination bar, and the sort dropdown (`SEARCH.l`, `PAGE.l`,
  # `by_letter.l`, `sort_by_header.l`, the anonymous-user login
  # reminder, etc). These are inline content sitting *inside* an
  # already-real `<nav>` landmark declared elsewhere (or inside a
  # `<ul>`/`<form>` that dictates its own tag), never a landmark
  # themselves — element defaults to `<div>`; pass `element:` for the
  # `<li>`/`<strong>` shapes those callers need. Stays `<div>`/`<span>`
  # under BS4 too (`.navbar-text`'s canonical BS4 shape is `<span>`,
  # still non-landmark).
  #
  # Pass `variant:` (`:default` or `:inverse`) to render the *outer*
  # `.navbar` wrapper instead — this is the one shape that's usually a
  # real `<nav class="navbar navbar-{variant}">` landmark (top nav), so
  # `element:` defaults to `:nav` whenever `variant:` is given. The
  # sidebar's inverse-styled wrapper is the exception: it's a `.navbar
  # navbar-inverse` div used purely for background/text-color theming,
  # nested *inside* the sidebar's own real `<nav id="sidebar">` landmark
  # — nesting a second `<nav>` there for pure theming would be a
  # redundant landmark, so that caller explicitly overrides back to
  # `element: :div`. BS4 renames `navbar-inverse`/`navbar-default` to
  # `navbar-dark`/`navbar-light` (a color-scheme class, not landmark-
  # specific either) — add those to the variant union when that
  # migration lands rather than inventing a separate component.
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
  # @example Default <div class="navbar-text"> wrapper
  #   Navbar(class: "mx-0") { plain(:PAGE.l) }
  #
  # @example <li class="navbar-text"> wrapper
  #   Navbar(element: :li, class: "mx-0 hidden-xs") { plain("Sort by:") }
  #
  # @example The outer <nav class="navbar navbar-default"> landmark
  #   (element: :nav is the default here — variant: implies it)
  #   Navbar(variant: :default, id: "top_nav") { ... }
  #
  # @example A <div class="navbar navbar-inverse"> theming wrapper
  #   (explicit element: :div overrides the variant: nav default)
  #   Navbar(variant: :inverse, element: :div, class: "sidebar-nav",
  #          data_controller: "nav-active") { ... }
  #
  # @example The class-string constants
  #   a(href: url, class: class_names(Components::Navbar::LINK_CLASSES,
  #                                   "navbar-left"))
  #   form(class: class_names(Components::Navbar::FORM_CLASS, "px-0"))
  class Navbar < Base
    LINK_CLASSES = %w[navbar-link btn btn-lg px-0].freeze
    FORM_CLASS = "navbar-form"

    prop :element, _Nilable(Symbol), default: nil
    prop :variant, _Nilable(_Union(:default, :inverse)), default: nil
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      send(effective_element, **computed_attributes, &block)
    end

    private

    # `variant:` implies the outer `.navbar` landmark shape, so it
    # defaults `element:` to `:nav` - override explicitly (e.g. the
    # sidebar's theming-only div) when that default doesn't apply.
    def effective_element
      @element || (@variant ? :nav : :div)
    end

    def computed_attributes
      {
        class: class_names(base_class, @attributes[:class]),
        **@attributes.except(:class)
      }
    end

    def base_class
      @variant ? "navbar navbar-#{@variant}" : "navbar-text"
    end
  end
end
