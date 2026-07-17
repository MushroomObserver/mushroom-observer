# frozen_string_literal: true

# Shared "icon + optional text" rendering — the icon glyph plus a
# text `<span>` that's `.sr-only` (hidden, default) or visible (at
# `sm+`) when `show_text:` is truthy. Included by both
# `Components::Button::Content` (Button / Link::Get family) and
# `Components::Link::Icon`.
#
# Callers that need multiple icon/text pairs in a specific order
# (e.g. `Link::Icon`'s stateful icon + active-icon swap) call
# `render_icon_glyph` / `render_icon_text` separately rather than
# the fused `render_icon_with_text`, so the icons and text spans can
# still be grouped icon-then-icon, text-then-text.
module Components::IconWithText
  TEXT_VISIBLE_CLASSES = "d-none d-sm-inline pl-2"

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

  def render_icon_with_text(icon, content, show_text:, icon_class: nil,
                            icon_title: nil)
    render_icon_glyph(icon, html_class: icon_class, title: icon_title)
    render_icon_text(content, show_text: show_text)
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
