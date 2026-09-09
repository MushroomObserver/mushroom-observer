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
  # `variant:` (`:light` or `:dark`) is required — there's no
  # "no variant" fallback shape here. The inline `.navbar-text` label
  # pattern that sits *inside* a navbar is a different concept
  # entirely, not a `.navbar` despite the shared name prefix — see
  # `Components::Navbar::Text`.
  #
  # `element:` defaults to `:nav`, matching the common case; override
  # explicitly for the sidebar's theming-only div.
  #
  # Also holds several plain string/array constants (not renderable
  # shapes) for other `navbar-*` patterns that recur across the same
  # files but don't share one fixed DOM shape: `.navbar-link`
  # icon-buttons (sometimes a raw `<a>`, sometimes routed through
  # `Link(type: :icon, ...)`), `.navbar-form` (sometimes a real
  # `<form>` tag, sometimes a plain `<div>` wrapper, sometimes just a
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
  # `FORM_CLASS` (`.navbar-form`) is an MO-owned CSS hook now — BS4
  # drops the class entirely, but `mo/_layout.scss`/`_icons.scss`/
  # `_top_nav.scss` still style it directly, so the string value is
  # unchanged. `RIGHT_CLASS`/`LEFT_CLASS` hold BS4's margin-auto
  # utilities (`.ml-auto`/`.mr-auto`), replacing BS3's float-based
  # `.navbar-right`/`.navbar-left`. `NAV_CLASS` (`.navbar-nav`) is a
  # real Bootstrap class in both versions, flex-based under BS4
  # instead of float-based under BS3 — nothing to swap here beyond
  # BS4's own `.navbar-nav` rule already applying.
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

    # `p-0` is baked in (rather than left for each caller to add)
    # because Bootstrap's `.navbar` padding isn't zero by default -
    # every current caller wants zero, so callers shouldn't have to
    # remember it. `.p-0` is `!important` (`mo/_utilities.scss`), so a
    # future caller wanting different padding can't just add another
    # padding utility class alongside it and expect a predictable
    # winner - that'll need a dedicated mechanism (e.g. a `padding:`
    # prop), not a class override.
    def base_class
      "navbar navbar-#{@variant} p-0"
    end
  end
end
