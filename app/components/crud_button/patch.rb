# frozen_string_literal: true

class Components::CrudButton
  # PATCH-method `CrudButton`.
  #
  # @example
  #   render(Components::CrudButton::Patch.new(
  #     name: :ACTIVATE.l,
  #     target: account_activate_api_key_path(key.id)
  #   ))
  class Patch < Components::CrudButton
    def initialize(target:, name:, **args)
      args[:btn] ||= Components::Button::DEFAULT_BTN
      super(target: target, name: name, method: :patch, **args)
    end
  end
end
