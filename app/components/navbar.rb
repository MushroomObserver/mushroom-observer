# frozen_string_literal: true

module Components
  # The outer `.navbar` landmark wrapper — a real `<nav class="navbar
  # navbar-{variant}">` element (top nav), or occasionally a `<div>`
  # used purely for background/text-color theming (the sidebar's
  # inverse-styled wrapper, nested *inside* the sidebar's own real
  # `<nav id="sidebar">` landmark — nesting a second `<nav>` there for
  # pure theming would be a redundant landmark, so that caller
  # explicitly overrides `element:` back to `:div`).
  #
  # `variant:` (`:default` or `:inverse`) is required — there's no
  # "no variant" fallback shape here. The inline `.navbar-text` label
  # pattern that sits *inside* a navbar is a different concept
  # entirely, not a `.navbar` despite the shared name prefix — see
  # `Components::Navbar::Text`.
  #
  # `element:` defaults to `:nav`, matching the common case; override
  # explicitly for the sidebar's theming-only div. BS4 renames
  # `navbar-inverse`/`navbar-default` to `navbar-dark`/`navbar-light`
  # (a color-scheme class, not landmark-specific either) — add those
  # to the variant union when that migration lands rather than
  # inventing a separate component.
  #
  # Every instance also gets `navbar-flex` alongside `navbar` — MO's
  # BS3->BS4 navbar bridge class (unrelated to `.flex-bar`, the plain
  # 3-utility-class alias used standalone by sorter/search-bar/
  # pagination/etc — different name specifically so the two don't
  # read as the same concept). Co-occurring with `navbar` triggers a
  # compound SCSS rule (`.navbar.navbar-flex` in `mo/_top_nav.scss`)
  # that overrides the `.navbar` box-model properties BS4 drops or
  # reshapes (including padding — see `base_class` below), so both
  # real landmarks stay visually identical today while already being
  # expressed in BS4-forward terms.
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
  # @example The outer <nav class="navbar navbar-default"> landmark
  #   Navbar(variant: :default, id: "top_nav") { ... }
  #
  # @example A <div class="navbar navbar-inverse"> theming wrapper
  #   (explicit element: :div overrides the :nav default)
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
    prop :variant, _Union(:default, :inverse)
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template(&block)
      send(@element || :nav, **computed_attributes, &block)
    end

    private

    def computed_attributes
      {
        class: class_names(base_class, @attributes[:class]),
        **@attributes.except(:class)
      }
    end

    # `p-0` is baked in (rather than left for each caller to add)
    # because the bridge rule's `padding` is a real value, not a
    # no-op - every current caller wants zero, so callers shouldn't
    # have to remember it. `.p-0` is `!important`
    # (`mo/_utilities.scss`), so a future caller wanting *different*
    # padding can't just add another padding utility class alongside
    # it and expect a predictable winner - that'll need a real
    # mechanism (e.g. a `padding:` prop), not a class override.
    def base_class
      "navbar navbar-flex navbar-#{@variant} p-0"
    end
  end
end
