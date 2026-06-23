# frozen_string_literal: true

class Components::CRUDButton
  # PUT-method `CRUDButton`.
  #
  # @example
  #   render(Components::CRUDButton::Put.new(
  #     name: :show_project_leave.t,
  #     target: project_member_path(...)
  #   ))
  class Put < Components::CRUDButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :put, **args)
    end
  end
end
