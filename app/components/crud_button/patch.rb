# frozen_string_literal: true

class Components::CRUDButton
  # PATCH-method `CRUDButton`.
  #
  # @example
  #   render(Components::CRUDButton::Patch.new(
  #     name: :ACTIVATE.l,
  #     target: account_activate_api_key_path(key.id)
  #   ))
  class Patch < Components::CRUDButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :patch, **args)
    end
  end
end
