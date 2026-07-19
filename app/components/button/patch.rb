# frozen_string_literal: true

# PATCH-method button.
#
# @example
#   Button(type: :patch,
#     name: :activate.ti,
#     target: account_activate_api_key_path(key.id)
#   )
class Components::Button::Patch < Components::Button::CRUDBase
  def initialize(target:, name:, **)
    super(target: target, name: name, method: :patch, **)
  end
end
