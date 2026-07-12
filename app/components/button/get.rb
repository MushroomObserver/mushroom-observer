# frozen_string_literal: true

# GET link — delegates to `Components::Link::Get`, adding button styling.
# Defaults to `btn btn-default` (no variant needed for the common case).
# Pass `variant:` to override (e.g. `variant: :outline`, `variant: :strip`).
#
# @example via dispatcher
#   Button(type: :get,
#     name: "View", target: @herbarium
#   )
#
# @example btn-link variant (no btn frame, underlined)
#   Button(type: :get,
#     name: user.login, target: user, variant: :link
#   )
class Components::Button::Get < Components::Link::Get
  def initialize(name:, target:, variant: nil, **)
    super(name: name, target: target, button: variant, **)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
