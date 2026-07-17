# frozen_string_literal: true

# Renders a Font Awesome Free (solid style) `<span>` with the MO
# `link-icon` class added. Optionally adds a tooltip + screen-reader
# title.
#
# @example Just the glyph
#   Icon(type: :globe)
#   # => <span class="fa-solid fa-earth-americas link-icon"></span>
#
# @example With tooltip + screen-reader title + extra CSS
#   Icon(type: :edit, title: :EDIT.l, class: "text-primary")
#   # => <span class="fa-solid fa-pen-to-square link-icon text-primary"
#   #          title="Edit" data-toggle="tooltip">
#   #      <span class="sr-only">Edit</span>
#   #    </span>
class Components::Icon < Components::Base
  # Glyph name lookup — `Components::Icon.new(type: :edit)` resolves
  # `:edit` to the Font Awesome Free solid-style icon name `edit`,
  # emitted as `fa-solid fa-pen-to-square`. Callers across the codebase
  # pass the semantic symbol; this table is the only place the Font
  # Awesome icon name is hardcoded. Picked via the side-by-side
  # comparison page in #4775 (Bootstrap 3 Glyphicons -> Font Awesome).
  GLYPHS = {
    edit: "pen-to-square",
    delete: "circle-xmark",
    add: "plus",
    back: "backward-step",
    show: "eye",
    hide: "eye-slash",
    reuse: "arrows-turn-right",
    x: "xmark",
    remove: "circle-xmark",
    send: "paper-plane",
    log_in: "right-to-bracket",
    log_out: "right-from-bracket",
    admin: "a",
    inbox: "inbox",
    interests: "bullhorn",
    settings: "gear",
    ban: "ban",
    plus: "circle-plus",
    minus: "circle-minus",
    trash: "trash-can",
    cancel: "xmark",
    email: "envelope",
    question: "circle-question",
    alert: "triangle-exclamation",
    list: "list-ul",
    copy: "clipboard-check",
    clone: "copy",
    merge: "arrow-right-arrow-left",
    move: "shuffle",
    adjust: "up-down",
    make_default: "star",
    publish: "circle-up",
    check: "circle-check",
    deprecate: "circle-check", # approved name needs to look "approved"
    approve: "circle-exclamation", # deprecated name needs to look "deprecated"
    synonyms: "shuffle",
    tracking: "bullhorn",
    manage_lists: "list-check",
    observations: "tags",
    print: "print",
    globe: "earth-americas",
    find_on_map: "location-crosshairs",
    apply: "square-check",
    chevron_down: "chevron-down",
    chevron_up: "chevron-up",
    chevron_left: "chevron-left",
    chevron_right: "chevron-right",
    qrcode: "qrcode",
    mobile: "mobile-screen-button",
    project: "diagram-project",
    download: "download",
    new_window: "up-right-from-square",
    search: "magnifying-glass",
    prev: "caret-left",
    next: "caret-right",
    goto: "share",
    grid: "table-cells",
    menu: "bars",
    info: "circle-question",
    fullscreen: "maximize",
    matrix: "table-cells-large",
    info_circle: "circle-info",
    user: "user"
  }.freeze

  prop :type, _Nilable(Symbol), default: nil
  prop :title, _Nilable(String), default: nil
  # Catch-all for class:, data:, aria:, and any other HTML attrs --
  # matches Components::Navbar/Collapsible's pattern (plain `class:`/
  # `data:` in, no separate `html_class:`/`data:` props needed).
  # `_Any?`, not bare `_Any` -- Literal's `_Any` excludes `NilClass`,
  # so a caller passing an explicit `key: nil` (not just omitting the
  # key) would otherwise raise a Literal::TypeError.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    glyph = GLYPHS[@type]
    return unless glyph

    span(class: span_class(glyph),
         title: @title.presence,
         data: span_data,
         **@attributes.except(:class, :data)) do
      span(class: "sr-only") { plain(@title) } if @title.present?
    end
  end

  private

  def span_class(glyph)
    base = "fa-solid fa-#{glyph} link-icon"
    class_names(base, @attributes[:class])
  end

  def span_data
    data = @attributes[:data] || {}
    @title.present? ? { toggle: "tooltip" }.merge(data) : data
  end
end
