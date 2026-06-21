# frozen_string_literal: true

# POST-method button.
#
# @example
#   render(Components::Button::Post.new(
#     name: :show_project_join.l,
#     target: project_members_path(project_id: @project.id)
#   ))
class Components::Button::Post < Components::Button::CRUDBase
  def initialize(target:, name:, style: BTN_DEFAULT_STYLE, **)
    super(target: target, name: name, method: :post, style: style, **)
  end
end
