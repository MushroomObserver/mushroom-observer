# frozen_string_literal: true

# Base class for all `Components::Link::*` components. Declares the
# `button:` prop that controls optional Bootstrap button styling: omit
# for a plain unstyled link; pass a variant symbol (e.g. `:outline`,
# `:btn_link`) to frame the link as a button.
#
# Subclasses using Literal props inherit `button:` automatically.
# Subclasses with a manual `initialize` (e.g. `Link::Get`) accept
# `button:` as a named kwarg and pass it through via `super(button:)`.
class Components::Link < Components::Base
  include Components::ButtonStyling
  include Components::ButtonContent

  prop :button, _Nilable(Symbol), default: nil

  private

  # Returns the btn class string when `button:` is set, or nil for a
  # plain link. Intentionally different from `Button#btn_styling`:
  # nil here means "plain link", not "btn-default".
  def btn_styling
    return nil unless @button
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
