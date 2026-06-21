# frozen_string_literal: true

# POST-method button.
#
# @example
#   render(Components::Button::Post.new(
#     name: :show_project_join.l,
#     target: project_members_path(project_id: @project.id)
#   ))
class Components::Button::Post < Components::Button::CRUDBase
  def initialize(target:, name:, variant: BTN_DEFAULT_VARIANT, **)
    super(target: target, name: name, method: :post, variant: variant, **)
  end
end
