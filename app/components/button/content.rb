# frozen_string_literal: true

# Shared `button_content` for icon+label rendering used by both
# `Components::Button` and `Components::Link`.
#
# When `@icon` is set:
#   - icon always renders first
#   - label (`@name`) follows in `span.sr-only` by default, or in
#     `span.d-none.d-sm-inline.ml-1` when `@label` is truthy
#     (visible at sm+ breakpoints, hidden on xs — for nav buttons
#     that show an icon on mobile and icon+text on wider screens)
# When only `@name` is set: plain text, no span wrapper.
module Components::Button::Content
  private

  def button_content
    if @icon
      render(Components::Icon.new(type: @icon, html_class: @icon_class,
                                  title: @icon_title))
      if @name
        label_class = @label ? "d-none d-sm-inline ml-1" : "sr-only"
        span(class: label_class) { trusted_html(@name) }
      end
    elsif @name
      trusted_html(@name)
    end
  end
end
