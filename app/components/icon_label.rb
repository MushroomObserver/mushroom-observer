# frozen_string_literal: true

# Shared "icon + optional label" rendering — the icon glyph plus a
# label `<span>` that's `.sr-only` (hidden, default) or visible (at
# `sm+`) when `show_text:` is truthy. Included by both
# `Components::Button::Content` (Button / Link::Get family) and
# `Components::Link::Icon`, which previously hand-rolled two
# slightly different versions of the same rendering (and disagreed
# on the visible-label spacing class: `ml-1` vs `pl-2` — standardized
# here on `pl-2`).
#
# Callers that need multiple icon/label pairs in a specific order
# (e.g. `Link::Icon`'s stateful icon + active-icon swap) call
# `render_icon_glyph` / `render_icon_label` separately rather than
# the fused `render_icon_with_label`, so the icons and labels can
# still be grouped icon-then-icon, label-then-label.
module Components::IconLabel
  LABEL_VISIBLE_CLASSES = "d-none d-sm-inline pl-2"

  private

  def render_icon_glyph(icon, html_class: nil, title: nil)
    render(Components::Icon.new(type: icon, html_class: html_class,
                                title: title))
  end

  def render_icon_label(content, show_text:, extra_class: nil)
    return unless content

    classes = class_names(show_text ? LABEL_VISIBLE_CLASSES : "sr-only",
                          extra_class)
    span(class: classes) { trusted_or_plain(content) }
  end

  def render_icon_with_label(icon, content, show_text:, icon_class: nil,
                             icon_title: nil)
    render_icon_glyph(icon, html_class: icon_class, title: icon_title)
    render_icon_label(content, show_text: show_text)
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
