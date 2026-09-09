# frozen_string_literal: true

# Responsive grid layout for displaying a collection of Grid::Box
# items. Renders as a `<ul>` with Bootstrap 4's `row-cols-*`
# utilities (see ROW_COLS_CLASSES) -- can render a collection of
# objects or accept a block for custom content.
#
# @example With block
#   render(Grid.new) do |grid|
#     grid.render(Grid::Box.new(id: 1) { "Content" })
#     grid.render(Grid::Box.new(id: 2) { "Content" })
#   end
#
# @example With collection of objects
#   render(Grid.new(objects: @observations, user: @user))
#
# @example With caching enabled
#   render(Grid.new(
#     objects: @observations,
#     user: @user,
#     cached: true
#   ))
#
# @example With identify mode enabled
#   render(Grid.new(
#     objects: @observations,
#     user: @user,
#     identify: true
#   ))
class Components::Grid < Components::Base
  # Bump when the rendered Grid::Box HTML changes (or any
  # observable behavior the cached fragment captures). This is the
  # invalidation lever for cached `Grid::Box` fragments — both the
  # write site (`render_cached_boxes`) and the controller's
  # pre-check (`ApplicationController::Indexes#uncached_object_ids`)
  # read this through `cache_key_for`. Phlex's automatic class +
  # method + line digest doesn't survive into the controller's
  # check, so we encode the version explicitly.
  # v2: image URLs in the fragment now carry a cache-busting
  # ?<updated_at> token (#4808) -- fragments cached under v1 embed
  # tokenless URLs and must be regenerated.
  # v3: Bootstrap 4 cutover -- Components::Panel now renders
  # `.card`/`.card-header`/`.card-body`/`.card-footer` instead of
  # `.panel`/`.panel-heading`/`.panel-body`/`.panel-footer`; fragments
  # cached under v2 embed the old classes and must be regenerated.
  # v4: the box's `.rss-*` classes (rss-box-details, rss-what,
  # rss-heading, etc.) are renamed to `.log-*`; fragments cached
  # under v3 embed the old class names and must be regenerated.
  # v5: source-credit markup flattened to a single
  # `.log-source-credit` div (was `.small` > `.source-credit` >
  # `small`); fragments cached under v4 embed the old nesting.
  # v6: `Matrix::Box` renamed to `Grid::Box` (`.matrix-box` -> `.grid-box`,
  # `context: "matrix_box"` -> `"grid_box"`), and the `small`/`.small`
  # wraps on log-where/log-what/source-credit/occurrence-link/
  # log-detail/log-updated-at were dropped in favor of a single
  # `.log-text` class on the details/footer wrap; fragments cached
  # under v5 embed the old class names and nesting.
  # v7: the details/footer lines (log-where, log-when-who [renamed
  # from log-what], log-source-credit, occurrence-link, log-detail,
  # log-updated-at) moved from bare `div`s to `li.hanging-indent`
  # inside a `ul.list-unstyled`; fragments cached under v6 embed the
  # old div-based markup.
  # v8: the title's `IDBadge` moved out of the `<h5>` into a sibling
  # `div.log-heading` wrapping both; fragments cached under v7 embed
  # the badge inside the heading tag.
  # v9: the title's `IDBadge` size changed from `:md` to `:lg`;
  # fragments cached under v8 embed the smaller badge class.
  # v10: trailing periods removed from the `log_*` rss-detail
  # translations, and `log_comment_*` now render a dedicated literal
  # template with a `<br>` before the summary instead of delegating
  # to the shared `log_object_*_by_user_with_name` keys; fragments
  # cached under v9 embed the old text.
  CACHE_VERSION = "v10"

  # The cache key Grid::Box fragments are stored under, used by both
  # the write inside this component and the controller's batched
  # `read_multi` pre-check in
  # `ApplicationController::Indexes#uncached_object_ids`. Keeping
  # both ends on one method ensures they agree on the key shape.
  #
  # Folds in the thumb image record itself so the expanded key tracks
  # the thumb's updated_at (cache_versioning is off in MO, so an AR
  # object in the key array expands via cache_key, which embeds its
  # updated_at timestamp). The rendered HTML embeds the thumb's URL,
  # tokened on that same updated_at (#4808), so the fragment must bust
  # whenever it changes. `object` alone isn't enough:
  # Verifier#mark_transferred touch_all's related Observations when a
  # transfer completes, but RssLogs don't get touched, so an RssLog
  # box cached before a rotate would otherwise serve the pre-rotate
  # URL token indefinitely. (An `Image` object IS its thumb and
  # already keys on that timestamp via `object` --
  # `try(:thumb_image)` is nil there, which is fine.)
  def self.cache_key_for(object, locale)
    ["Grid::Box", CACHE_VERSION, locale, object, object.try(:thumb_image)]
  end

  # Per-object predicate the render path uses to decide whether to
  # write the fragment cache (`render_cached_boxes`) AND the
  # controller's pre-check uses to decide whether to consult it
  # (`ApplicationController::Indexes#uncached_object_ids`).
  # Objects with an untransferred thumb_image are skipped — the
  # rendered HTML embeds the image URL, which would be wrong (and
  # wrongly cached) until the transfer completes. An `Image` object
  # (images/index) has no `thumb_image` to defer to -- it IS
  # the thumb -- so check its `transferred` directly instead of
  # falling through the `respond_to?` guard to an unconditional true.
  def self.should_cache_object?(object)
    return object.transferred != false if object.is_a?(::Image)
    return true unless object.respond_to?(:thumb_image)

    object.thumb_image&.transferred != false
  end

  # Properties
  prop :objects, _Nilable(Array), default: nil
  prop :user, _Nilable(User), default: nil
  prop :cached, _Boolean, default: false
  prop :identify, _Boolean, default: false
  # Project context — passed through to each Grid::Box so a project admin
  # sees an Exclude button on the observations grid filtered by project.
  prop :project, _Nilable(Project), default: nil

  # Matches the breakpoint/count mapping the old BS4 prototype used
  # (`origin/nimmo-bootstrap-4-reboot:app/views/shared/
  # _matrix_grid.html.erb`) -- BS4's `row-cols-{bp}-{n}` utilities size
  # every direct child of the row equally, so `Components::Grid::Box`
  # doesn't need a per-breakpoint width class -- just the bare `.col`
  # default (see its `columns` prop).
  ROW_COLS_CLASSES = "row-cols-1 row-cols-sm-2 row-cols-md-3 row-cols-xl-4"

  def view_template(&block)
    Row(
      element: :ul,
      class: class_names(ROW_COLS_CLASSES, "list-unstyled mt-3")
    ) do
      if block
        yield
      elsif @cached && @objects
        render_cached_boxes
      elsif @objects
        render_boxes
      end
    end

    render_vote_interface_streams if !block && @objects
    div(class: "clearfix")
  end

  # Overrides Components::Base#cache_store for the duration of a
  # #render_cached_boxes call -- see BatchedCacheStore.
  def cache_store
    @batched_store || super
  end

  private

  def render_cached_boxes
    @batched_store = build_batched_store

    @objects.each do |object|
      if cacheable_render?(object)
        # `low_level_cache` with the deterministic key from
        # `cache_key_for` — same key the controller pre-check uses.
        # Talks to `cache_store` (overridden above), unaware it's the
        # batched wrapper rather than Rails.cache directly.
        low_level_cache(
          self.class.cache_key_for(object, I18n.locale)
        ) { render(Components::Grid::Box.new(user: @user, object: object)) }
      else
        render(Components::Grid::Box.new(
                 user: @user, object: object,
                 identify: @identify, project: @project
               ))
      end
    end
  ensure
    # Runs even if a box raised partway through -- flushes whatever
    # was already computed instead of silently discarding it. Cleared
    # afterward so a stray later #cache_store call (component reuse,
    # an unrelated caching need) falls through to Rails.cache instead
    # of a stale, already-flushed wrapper.
    @batched_store&.flush_writes!
    @batched_store = nil
  end

  # Skip the batched store (and its upfront read_multi) entirely when
  # caching is off -- `low_level_cache` (phlex-rails) already yields
  # unconditionally in that case and doesn't touch `cache_store`, so
  # building it here would be a wasted DB round trip.
  def build_batched_store
    return unless Rails.application.config.action_controller.perform_caching

    BatchedCacheStore.new(Rails.cache, cacheable_keys)
  end

  def cacheable_keys
    @objects.select { |object| cacheable_render?(object) }.
      map { |object| self.class.cache_key_for(object, I18n.locale) }
  end

  # Mirrors the controller's `grid_caches_in_this_request?` AND
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

  def render_boxes
    @objects.each do |object|
      render(Components::Grid::Box.new(
               user: @user, object: object,
               identify: @identify, project: @project
             ))
    end
  end

  # Fills every box's empty vote-interface frame in one uncached pass —
  # viewer-specific content that must stay out of the shared box
  # fragments, but shouldn't cost one frame-src request per image
  # either. RssLog boxes have no thumb_image accessor; their frames
  # keep the per-frame lazy fetch.
  def render_vote_interface_streams
    images = @objects.filter_map do |object|
      object.is_a?(::Image) ? object : object.try(:thumb_image)
    end
    return if images.empty?

    ImageFragment(type: :vote_interface_streams, images: images,
                  user: @user)
  end
end
