# frozen_string_literal: true

# Shared content rendering for collapse-toggle components. Included by
# both `Components::Button::CollapseToggle` and
# `Components::Link::CollapseToggle`. Renders an optional icon (with title
# defaulting to the toggle text when not explicitly supplied) followed by
# `span.collapse-toggle-open` and `span.collapse-toggle-closed` spans.
# CSS keyed off Bootstrap's `.collapsed` class on the trigger element
# swaps which span is visible based on the collapse state.
module Components::Button::CollapseContent
  private

  def collapse_content
    if @icon
      render(Components::Icon.new(
               type: @icon, class: @icon_class,
               title: @icon_title || @open_text || @closed_text
             ))
    end
    if @open_text
      span(class: text_span_class("collapse-toggle-open")) { plain(@open_text) }
    end
    return unless @closed_text

    span(class: text_span_class("collapse-toggle-closed")) do
      plain(@closed_text)
    end
  end

  # `icon-text-gap` (see Components::IconWithText, _icons.scss) --
  # only needed when an icon glyph precedes the text.
  def text_span_class(base)
    class_names(base, "icon-text-gap" => @icon)
  end
end
