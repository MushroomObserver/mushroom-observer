# frozen_string_literal: true

class Components::CrudButton
  # PUT-method `CrudButton`.
  #
  # @example
  #   render(Components::CrudButton::Put.new(
  #     name: :show_project_leave.t,
  #     target: project_member_path(...)
  #   ))
  class Put < Components::CrudButton
    def initialize(target:, name:, **args)
      unless args.key?(:style)
        args[:style] =
          Components::Button::DEFAULT_STYLE
      end
      super(target: target, name: name, method: :put, **args)
    end
  end
end
