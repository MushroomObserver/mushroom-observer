# frozen_string_literal: true

# Matrix table component for displaying grids of matrix boxes.
#
# Renders a responsive grid layout with Stimulus controller for dynamic
# resizing. Can render a collection of objects or accept a block for
# custom content.
#
# @example With block
#   render(MatrixTable.new) do |table|
#     table.render(MatrixBox.new(id: 1) { "Content" })
#     table.render(MatrixBox.new(id: 2) { "Content" })
#   end
#
# @example With collection of objects
#   render(MatrixTable.new(objects: @observations, user: @user))
#
# @example With caching enabled
#   render(MatrixTable.new(
#     objects: @observations,
#     user: @user,
#     cached: true
#   ))
#
# @example With identify mode enabled
#   render(MatrixTable.new(
#     objects: @observations,
#     user: @user,
#     identify: true
#   ))
class Components::MatrixTable < Components::Base
  # Properties
  prop :objects, _Nilable(Array), default: nil
  prop :user, _Nilable(User), default: nil
  prop :cached, _Boolean, default: false
  prop :identify, _Boolean, default: false
  # Project context — passed through to each MatrixBox so a project admin
  # sees an Exclude button on the observations grid filtered by project.
  prop :project, _Nilable(Project), default: nil

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
      # Skip fragment cache only when the current user will see the
      # admin-only Exclude button. Non-admins see the same output as the
      # non-project case, so caching is still safe for them.
      if !@identify && !project_admin_view? && should_cache_object?(object)
        cache([I18n.locale, object]) do
          MatrixBox(user: @user, object: object)
        end
      else
        MatrixBox(user: @user, object: object,
                  identify: @identify, project: @project)
      end
    end
  end

  def project_admin_view?
    @project&.is_admin?(@user)
  end

  def should_cache_object?(object)
    return true unless object.respond_to?(:thumb_image)

    # Don't cache if thumb_image hasn't been transferred to image server
    object.thumb_image&.transferred != false
  end

  def render_matrix_boxes
    @objects.each do |object|
      MatrixBox(user: @user, object: object,
                identify: @identify, project: @project)
    end
  end
end
