# frozen_string_literal: true

# Shared `button_content` for icon+label rendering used by both
# `Components::Button` and `Components::Link`. Delegates the actual
# icon/label markup to `Components::IconLabel`.
#
# When `@icon` is set:
#   - icon always renders first
#   - label (`@name`) follows in `span.sr-only` by default, or in
#     `span.d-none.d-sm-inline.pl-2` when `@label` is truthy
#     (visible at sm+ breakpoints, hidden on xs — for nav buttons
#     that show an icon on mobile and icon+text on wider screens)
# When only `@name` is set: plain text, no span wrapper.
module Components::Button::Content
  include Components::IconLabel

  private

  def button_content
    if @icon
      render_icon_with_label(@icon, @name, show_text: @label,
                                           icon_class: @icon_class,
                                           icon_title: @icon_title)
    elsif @name
      trusted_or_plain(@name)
    end
  end
end
