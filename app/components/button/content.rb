# frozen_string_literal: true

# Shared `button_content` for icon+text rendering used by both
# `Components::Button` and `Components::Link`. Delegates the actual
# icon/text markup to `Components::IconWithText`.
#
# When `@icon` is set:
#   - icon always renders first
#   - text (`@name`) follows in `span.sr-only` by default, or in
#     `span.d-none.d-sm-inline` when `@label` is truthy
#     (visible at sm+ breakpoints, hidden on xs — for nav buttons
#     that show an icon on mobile and icon+text on wider screens)
# When only `@name` is set: plain text, no span wrapper.
module Components::Button::Content
  include Components::IconWithText

  private

  def button_content
    if @icon
      render_icon_with_text(
        @icon, @name, show_text: @label,
                      icon_opts: { class: @icon_class, title: @icon_title },
                      active: { icon: @active_icon, content: @active_content }
      )
    elsif @name
      trusted_or_plain(@name)
    end
  end

  # `.stateful-link` is what `_icons.scss`'s active/collapsed swap
  # rule keys off -- only add it when there's actually a swap pair to
  # show/hide, so a plain (non-stateful) Button/Link's markup is
  # unaffected. Shared here (both `Components::Button#merged_class`
  # and `Components::Link::Get#merged_class` call it) rather than
  # duplicated.
  def stateful_class
    "stateful-link" if @active_icon && @active_content
  end
end
