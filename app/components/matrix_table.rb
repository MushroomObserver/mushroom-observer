# frozen_string_literal: true

# Matrix table component for displaying grids of matrix boxes.
#
# Renders a responsive grid layout with Stimulus controller for dynamic
# resizing. Can render a collection of objects or accept a block for
# custom content.
#
# @example With block
#   render MatrixTable.new do
#     render MatrixBox.new(id: 1) { "Content" }
#     render MatrixBox.new(id: 2) { "Content" }
#   end
#
# @example With collection of objects
#   render MatrixTable.new(objects: @observations, user: @user)
#
# @example With caching enabled
#   render MatrixTable.new(
#     objects: @observations,
#     user: @user,
#     cached: true
#   )
#
# @example With collection and local options
#   render MatrixTable.new(
#     objects: @observations,
#     user: @user,
#     locals: { identify: true }
#   )
class Components::MatrixTable < Components::Base
  # Properties
  prop :objects, _Nilable(Array), default: nil
  prop :user, _Nilable(User), default: nil
  prop :cached, _Boolean, default: false
  prop :locals, Hash, default: -> { {} }

  def view_template(&block)
    ul(
      class: "row list-unstyled mt-3",
      data: {
        controller: "matrix-table",
        action: "resize@window->matrix-table#rearrange"
      }
    ) do
      if block
        yield
      elsif @cached && @objects
        render_cached_boxes
      elsif @objects
        render_matrix_boxes
      end
    end

    div(class: "clearfix")
  end

  private

  def render_cached_boxes
    @objects.each do |object|
      cache(object) do
        render(MatrixBox.new(user: @user, object: object, **@locals))
      end
    end
  end

  def render_matrix_boxes
    @objects.each do |object|
      render(MatrixBox.new(user: @user, object: object, **@locals))
    end
  end
end
