# frozen_string_literal: true

# GET button — emits `<a>` (link_to), not a form-wrapped button.
# Idempotent navigations (edit, download, etc.) use this rather than
# the form-button branch. Pass `action:` to trigger named-route
# prefixing for model targets (`:edit`, `:new`, `:download`).
#
# @example edit link via a model target
#   render(Components::Button.new(type: :get,
#     target: @herbarium, action: :edit, icon: :edit
#   ))
class Components::Button::Get < Components::Button::CRUDBase
  def initialize(target:, name:, **)
    super(target: target, name: name, method: :get, **)
  end
end
