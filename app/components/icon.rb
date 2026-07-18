# frozen_string_literal: true

# Renders a Bootstrap 3 Glyphicon `<span>` with the MO `link-icon`
# class added. Optionally adds a tooltip + screen-reader title.
#
# @example Just the glyph
#   Icon(type: :globe)
#   # => <span class="glyphicon glyphicon-globe link-icon"></span>
#
# @example With tooltip + screen-reader title + extra CSS
#   Icon(type: :edit, title: :EDIT.l, class: "text-primary")
#   # => <span class="glyphicon glyphicon-edit link-icon text-primary"
#   #          title="Edit" data-trigger="tooltip">
#   #      <span class="sr-only">Edit</span>
#   #    </span>
class Components::Icon < Components::Base
  # Glyph name lookup — `Components::Icon.new(type: :edit)` resolves
  # `:edit` to the Bootstrap glyphicon class suffix `edit`, emitted as
  # `glyphicon glyphicon-edit`. Callers across the codebase pass the
  # semantic symbol; this table is the only place the glyphicon name
  # is hardcoded.
  GLYPHS = {
    edit: "edit",
    delete: "remove-circle",
    add: "plus",
    back: "step-backward",
    show: "eye-open",
    hide: "eye-close",
    reuse: "share",
    x: "remove",
    remove: "remove-circle",
    send: "send",
    log_in: "log-in",
    log_out: "log-out",
    admin: "text-background",
    inbox: "inbox",
    interests: "bullhorn",
    settings: "cog",
    ban: "ban-circle",
    plus: "plus-sign",
    minus: "minus-sign",
    trash: "trash",
    cancel: "remove",
    email: "envelope",
    question: "question-sign",
    alert: "alert",
    list: "list",
    copy: "copy",
    clone: "duplicate",
    merge: "transfer",
    move: "random",
    adjust: "resize-vertical",
    make_default: "star",
    publish: "upload",
    check: "ok-circle",
    deprecate: "ok-circle", # approved name needs to look "approved"
    approve: "exclamation-sign", # deprecated name needs to look "deprecated"
    synonyms: "random",
    tracking: "bullhorn",
    manage_lists: "indent-left",
    observations: "tags",
    print: "print",
    globe: "globe",
    map: "globe",
    place: "map-marker",
    find_on_map: "screenshot",
    apply: "check",
    chevron_down: "chevron-down",
    chevron_up: "chevron-up",
    chevron_left: "chevron-left",
    chevron_right: "chevron-right",
    qrcode: "qrcode",
    mobile: "phone",
    project: "th-list",
    download: "download-alt",
    new_window: "new-window",
    search: "search",
    prev: "triangle-left",
    next: "triangle-right",
    goto: "share-alt",
    grid: "th",
    menu: "align-justify",
    info: "question-sign",
    fullscreen: "fullscreen",
    matrix: "th-large",
    info_circle: "info-sign",
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
    base = "glyphicon glyphicon-#{glyph} link-icon"
    class_names(base, @attributes[:class])
  end

  def span_data
    data = @attributes[:data] || {}
    @title.present? ? { trigger: "tooltip" }.merge(data) : data
  end
end
