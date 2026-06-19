# frozen_string_literal: true

class Components::CrudButton
  # POST-method `CrudButton`.
  #
  # @example
  #   render(Components::CrudButton::Post.new(
  #     name: :show_project_join.l,
  #     target: project_members_path(project_id: @project.id)
  #   ))
  class Post < Components::CrudButton
    def initialize(target:, name:, **args)
      args[:btn] = Components::Button::DEFAULT_BTN unless args.key?(:btn)
      super(target: target, name: name, method: :post, **args)
    end
  end
end
