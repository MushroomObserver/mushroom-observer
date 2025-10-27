# frozen_string_literal: true

# Matrix table component for displaying grids of matrix boxes.
#
# Renders a responsive grid layout with Stimulus controller for dynamic resizing.
# Can render a collection of objects or accept a block for custom content.
#
# @example With block
#   render MatrixTable.new do
#     render MatrixBox.new(id: 1) { "Content" }
#     render MatrixBox.new(id: 2) { "Content" }
#   end
#
# @example With collection
#   render MatrixTable.new(objects: @observations, partial: "shared/matrix_box")
class Components::MatrixTable < Components::Base
  # Properties
  prop :objects, _Nilable(Array), default: nil
  prop :partial, String, default: "shared/matrix_box"
  prop :as, Symbol, default: :object
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
      elsif cached && objects
        render_cached_boxes
      elsif objects
        render_collection
      end
    end

    div("", class: "clearfix")
  end

  private

  def render_cached_boxes
    objects.each do |object|
      helpers.cache(object) do
        unsafe_raw(
          helpers.render(
            partial: partial,
            locals: locals.merge(as => object)
          )
        )
      end
    end
  end

  def render_collection
    unsafe_raw(
      helpers.render(
        partial: partial,
        collection: objects,
        as: as,
        locals: locals
      )
    )
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
