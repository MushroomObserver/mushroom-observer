# frozen_string_literal: true

# POST-method button.
#
# @example
#   Button(type: :post,
#     name: :show_project_join.l,
#     target: project_members_path(project_id: @project.id)
#   )
class Components::Button::Post < Components::Button::CRUDBase
  def initialize(target:, name:, **)
    super(target: target, name: name, method: :post, **)
  end
end
