# frozen_string_literal: true

# Shared "icon + optional text" rendering — the icon glyph plus a
# text `<span>` that's `.sr-only` (hidden, default) or visible (at
# `sm+`) when `show_text:` is truthy. Included by
# `Components::Button::Content`, in turn included by both
# `Components::Button` and `Components::Link` (the `Link::Get` family)
# -- so both get the optional active-icon/active-label swap below for
# free.
#
# `render_icon_with_text` renders icon-then-text by default; passing
# `active_icon:`/`active_content:` additionally renders a second
# icon/text pair (marked `.active-icon`/`.active-label`), for a
# target whose appearance swaps based on state (e.g. a bookmark/
# subscribe toggle) -- CSS keys visibility off a `.active`/`.collapsed`
# class on the trigger element (see `_icons.scss`'s `.stateful-link`
# rule).
module Components::IconWithText
  # `icon-text-gap`, not a `.pl-*` rem-based utility -- the gap needs
  # to scale with the surrounding font-size (a `.panel-title` heading's
  # bold type needs visibly more gap than small body text), which only
  # an em-based value does. See `_icons.scss` for the rule.
  TEXT_VISIBLE_CLASSES = "d-none d-sm-inline icon-text-gap"

  private

  # `render(...)`, not Kit syntax -- this module is included at varying
  # nesting depths (Components::Button::Content, itself included by
  # deeply-nested dispatched subclasses like Components::Button::Edit),
  # and Kit syntax's bare `Icon(...)` isn't reliably available that far
  # down the chain.
  def render_icon_glyph(icon, html_class: nil, title: nil)
    render(Components::Icon.new(type: icon, class: html_class,
                                title: title))
  end

  def render_icon_text(content, show_text:, extra_class: nil)
    return unless content

    classes = class_names(show_text ? TEXT_VISIBLE_CLASSES : "sr-only",
                          extra_class)
    span(class: classes) { trusted_or_plain(content) }
  end

  def render_icon_with_text(icon, content, show_text:, icon_opts: {},
                            active: {})
    render_icon_glyph(icon, html_class: icon_opts[:class],
                            title: icon_opts[:title])
    render_icon_text(content, show_text: show_text)
    return unless active[:icon] && active[:content]

    render_icon_glyph(active[:icon],
                      html_class: class_names(icon_opts[:class],
                                              "active-icon"))
    render_icon_text(active[:content], show_text: show_text,
                                       extra_class: "active-label")
  end

  # Content can be a textile-rendered safe-buffer string (e.g. a
  # name's display_name). `plain` would re-escape it; `trusted_html`
  # emits it as-is. Plain Strings go through `plain` so user-typed
  # text is escaped normally.
  def trusted_or_plain(text)
    if text.is_a?(ActiveSupport::SafeBuffer)
      trusted_html(text)
    else
      plain(text)
    end
  end
end
