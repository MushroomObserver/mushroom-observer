# frozen_string_literal: true

class Components::CrudButton
  # PUT-method `CrudButton`. Used as the Phlex-side equivalent of
  # `LinkHelper#put_button` (which delegates here).
  #
  # @example
  #   render(Components::CrudButton::Put.new(
  #     name: :show_project_leave.t,
  #     target: project_member_path(...)
  #   ))
  class Put < Components::CrudButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :put, **args)
    end
  end
end
