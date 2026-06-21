# frozen_string_literal: true

# PUT-method button.
#
# @example
#   render(Components::Button::Put.new(
#     name: :show_project_leave.t,
#     target: project_member_path(...)
#   ))
class Components::Button::Put < Components::Button::CRUDBase
  def initialize(target:, name:, variant: BTN_DEFAULT_VARIANT, **)
    super(target: target, name: name, method: :put, variant: variant, **)
  end
end
