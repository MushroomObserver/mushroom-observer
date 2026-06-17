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
class Components::Matrix::Table < Components::Base
  # Bump when the rendered MatrixBox HTML changes (or any
  # observable behavior the cached fragment captures). This is the
  # invalidation lever for cached `MatrixBox` fragments — both the
  # write site (`render_cached_boxes`) and the controller's
  # pre-check (`ApplicationController::Indexes#object_fragment_exist?`)
  # read this through `cache_key_for`. Phlex's automatic class +
  # method + line digest doesn't survive into the controller's
  # check, so we encode the version explicitly.
  # Bumped from "v1" to "v2" on the matrix-carousels tryout: multi-image
  # observations now render a `Components::Matrix::Carousel` in the
  # thumbnail slot rather than a single `Components::Image::Interactive`,
  # so old "v1" fragments would serve stale single-image HTML on
  # carousel-capable obs.
  CACHE_VERSION = "v2"

  # The cache key MatrixBox fragments are stored under, used by
  # both the Phlex `low_level_cache` write inside this component and
  # the controller's `Rails.cache.exist?` pre-check in
  # `ApplicationController::Indexes#object_fragment_exist?`. Keeping
  # both ends on one method ensures they agree on the key shape.
  def self.cache_key_for(object, locale)
    ["MatrixBox", CACHE_VERSION, locale, object]
  end

  # Per-object predicate the render path uses to decide whether to
  # write the fragment cache (`render_cached_boxes`) AND the
  # controller's pre-check uses to decide whether to consult it
  # (`ApplicationController::Indexes#object_fragment_exist?`).
  # Objects with an untransferred thumb_image are skipped — the
  # rendered HTML embeds the image URL, which would be wrong (and
  # the wrong-cached) until the transfer completes.
  def self.should_cache_object?(object)
    return true unless object.respond_to?(:thumb_image)

    object.thumb_image&.transferred != false
  end

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
      if cacheable_render?(object)
        # `low_level_cache` with the deterministic key from
        # `cache_key_for` — same key the controller pre-check uses.
        low_level_cache(
          self.class.cache_key_for(object, I18n.locale)
        ) { render(Components::Matrix::Box.new(user: @user, object: object)) }
      else
        render(Components::Matrix::Box.new(
                 user: @user, object: object,
                 identify: @identify, project: @project
               ))
      end
    end
  end

  # Mirrors the controller's `matrix_caches_in_this_request?` AND
  # `should_cache_object?` gates. Project admins see the admin-only
  # Exclude button; identify mode renders the vote selector. Both
  # diverge from the cached non-admin / non-identify markup, so the
  # cache must be bypassed.
  def cacheable_render?(object)
    !@identify && !project_admin_view? &&
      self.class.should_cache_object?(object)
  end

  def project_admin_view?
    @project&.is_admin?(@user)
  end

  def render_matrix_boxes
    @objects.each do |object|
      render(Components::Matrix::Box.new(
               user: @user, object: object,
               identify: @identify, project: @project
             ))
    end
  end
end
