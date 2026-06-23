# frozen_string_literal: true

class Components::CRUDButton
  # POST-method `CRUDButton`.
  #
  # @example
  #   render(Components::CRUDButton::Post.new(
  #     name: :show_project_join.l,
  #     target: project_members_path(project_id: @project.id)
  #   ))
  class Post < Components::CRUDButton
    def initialize(target:, name:, **args)
      super(target: target, name: name, method: :post, **args)
    end
  end
end
