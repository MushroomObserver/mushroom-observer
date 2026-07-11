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
    span(class: "collapse-toggle-open") { plain(@open_text) } if @open_text
    return unless @closed_text

    span(class: "collapse-toggle-closed") { plain(@closed_text) }
  end
end
