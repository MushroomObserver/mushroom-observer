# frozen_string_literal: true

module Components
  # The outer `.navbar` landmark wrapper — a `<nav class="navbar
  # navbar-{variant}">` element (top nav), or occasionally a `<div>`
  # used purely for background/text-color theming (the sidebar's
  # inverse-styled wrapper, nested *inside* the sidebar's
  # `<nav id="sidebar">` landmark — nesting a second `<nav>` there for
  # theming would be a redundant landmark, so that caller explicitly
  # overrides `element:` back to `:div`).
  #
  # `variant:` (`:light` or `:dark`) is required — there's no
  # "no variant" fallback shape here. The inline `.navbar-text` label
  # pattern that sits *inside* a navbar is a different concept, not a
  # `.navbar` despite the shared name prefix — see
  # `Components::Navbar::Text`.
  #
  # `element:` defaults to `:nav`, matching the common case; override
  # explicitly for the sidebar's theming-only div.
  #
  # Also holds several plain string/array constants (not renderable
  # shapes) for other `navbar-*` patterns that recur across the same
  # files but don't share one fixed DOM shape: `.navbar-link`
  # icon-buttons (sometimes a raw `<a>`, sometimes routed through
  # `Link(type: :icon, ...)`), `.navbar-form` (sometimes a `<form>`
  # tag, sometimes a plain `<div>` wrapper, sometimes just a
  # `wrapper_class:` string handed to another component like
  # `Dropdown`), and the `.navbar-nav`/`.navbar-right`/`.navbar-left`
  # trio that shapes the nav-item list inside a `.navbar` landmark. A
  # single Phlex tag-emitting component can't cover all these shapes,
  # so callers compose the constants with `class_names` instead.
  #
  # `LINK_CLASS`/`LINK_CLASSES` intentionally do NOT include
  # `btn`/`btn-lg` — `Components::Link::Get` (the shape every current
  # caller renders through) accepts `button:`/`size:` kwargs directly,
  # so callers pass `button: :link, size: :lg` instead of baking
  # Bootstrap button classes into a raw string constant. `LINK_CLASS`
  # is the bare `"navbar-link"` token for callers that need a
  # different spacing utility than `LINK_CLASSES`'s bundled `px-0`
  # (e.g. `search_bar.rb`, which wants `px-2`).
  #
  # `FORM_CLASS` (`.navbar-form`) is an MO-owned CSS hook — Bootstrap
  # has no such class, but `mo/_layout.scss`/`_icons.scss`/
  # `_top_nav.scss` style it directly. `RIGHT_CLASS`/`LEFT_CLASS` hold
  # Bootstrap's margin-auto utilities (`.ml-auto`/`.mr-auto`) for
  # aligning nav items to either end. `NAV_CLASS` (`.navbar-nav`) is a
  # Bootstrap class, flex-based, shaping the nav-item list.
  #
  # @example The outer <nav class="navbar navbar-light"> landmark
  #   Navbar(variant: :light, id: "top_nav") { ... }
  #
  # @example A <div class="navbar navbar-dark"> theming wrapper
  #   (explicit element: :div overrides the :nav default)
  #   Navbar(variant: :dark, element: :div, class: "sidebar-nav",
  #          data_controller: "nav-active") { ... }
  #
  # @example The class-string constants
  #   a(href: url, class: class_names(Components::Navbar::LINK_CLASSES,
  #                                   Components::Navbar::LEFT_CLASS))
  #   form(class: class_names(Components::Navbar::FORM_CLASS, "px-0"))
  #   ul(class: class_names(Components::Navbar::NAV_CLASS,
  #                         Components::Navbar::RIGHT_CLASS))
  class Navbar < Base
    LINK_CLASS = "navbar-link"
    LINK_CLASSES = [LINK_CLASS, "px-0"].freeze
    FORM_CLASS = "navbar-form"
    NAV_CLASS = "navbar-nav"
    RIGHT_CLASS = "ml-auto"
    LEFT_CLASS = "mr-auto"

    prop :element, Symbol, default: :nav
    prop :variant, _Union(:light, :dark)
    # Overrides the default zero padding -- see `base_class` below for
    # why this needs a dedicated prop instead of a class override.
    prop :padding, String, default: "p-0"
    # `_Any?`, not bare `_Any` -- Literal's `_Any` excludes `NilClass`,
    # so a caller passing an explicit `key: nil` (not just omitting the
    # key) would otherwise raise a Literal::TypeError.
    prop :attributes, _Hash(Symbol, _Any?), :**

    def view_template(&block)
      send(@element, **computed_attributes, &block)
    end

    private

    def computed_attributes
      {
        class: class_names(base_class, @attributes[:class]),
        **@attributes.except(:class)
      }
    end

    # `p-0` default since Bootstrap's `.navbar` padding isn't zero and
    # most callers want zero. Bootstrap padding utilities are all
    # `!important`, so a caller needing different padding must
    # override via `padding:`, not by adding another class alongside it.
    def base_class
      "navbar navbar-#{@variant} #{@padding}"
    end
  end
end
