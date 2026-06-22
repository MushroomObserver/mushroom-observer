# frozen_string_literal: true

# PUT-method button.
#
# @example
#   render(Components::Button.new(type: :put,
#     name: :show_project_leave.t,
#     target: project_member_path(...)
#   ))
class Components::Button::Put < Components::Button::CRUDBase
  def initialize(target:, name:, **)
    super(target: target, name: name, method: :put, **)
  end
end
