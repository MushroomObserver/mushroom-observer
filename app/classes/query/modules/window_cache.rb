# frozen_string_literal: true

##############################################################################
#
#  :module: WindowCache
#
#  Cached-window neighbor lookup for `Query::Modules::Sequence` --
#  serves prev/next/first/last from a window of ids around the current
#  position, keyed by `QueryRecord#id` and viewer.
#
#  The cached window is what gives prev/next stable snapshot semantics:
#  the pager walks the ordering as the viewer saw it on the index page,
#  instead of recomputing "the row after the current row's position
#  right now" on every click -- under live recomputation, a concurrent
#  edit that moves the current row within the ordering silently teleports
#  the viewer (e.g. clicking next from a row another user's vote just
#  re-sorted to the front lands back at the start of the list). Liveness
#  leaks back in only at the seams: recentering on walking off a window
#  edge, and TTL expiry (`WINDOW_TTL`).
#
#  Window fills go through a bounded keyset fetch when the query's
#  ORDER BY is a plain list of columns (`Query::Modules::Seek`) --
#  `window_radius` rows per direction, indexed -- and fall back to
#  slicing today's full `result_ids` computation for order shapes a
#  keyset predicate can't express (aggregates, CASE, FIND_IN_SET) or
#  when the current row's sort key is ambiguous across a to-many join.
#
##############################################################################

module Query::Modules::WindowCache
  WINDOW_TTL = 30.minutes

  private

  # Ids kept on each side of the current position. Derived from the
  # viewer: radius >= the viewer's index page size - 1 guarantees the
  # entire page they drilled in from is inside the window (worst case:
  # they clicked its first item); 2x gives a full page of margin each
  # direction. The clamp bounds the cache row at ~2-15KB.
  def window_radius
    @window_radius ||= 2 * (viewer&.layout_count || 60).clamp(60, 480)
  end

  # Scoped by viewer as well as QueryRecord -- `QueryRecord` dedups by
  # serialized query params only, so two different users browsing the
  # same logical query (e.g. everyone on the default unfiltered index)
  # would otherwise share one cache slot and continually evict each
  # other's window as they browse to different positions. No viewer
  # (a bot, or `create_query`'s callers that don't set one) means no
  # caching, rather than falling back to a shared anonymous slot --
  # the seek-backed fill keeps even uncached lookups bounded.
  def window_cache_key
    return nil unless record&.id && viewer&.id

    "query_window/#{record.id}/#{viewer.id}"
  end

  # Ids around `current_id`, `current_id`'s own index within them, and
  # whether each edge is the true edge of the full result set or just
  # where this window happens to stop -- or nil if `current_id` isn't
  # in the result set (deleted, no longer matches the filter).
  #
  # Everything downstream depends only on the returned shape, not on
  # which of the two fetch strategies computed it.
  def compute_window(current_id)
    seek_window(current_id) || full_scan_window(current_id)
  end

  # Bounded fetch: `window_radius` ids per direction via the keyset
  # predicate (`Query::Modules::Seek`), each edge flagged as true when
  # its fetch came up short of the radius. Returns nil -- falling back
  # to `full_scan_window` -- when the order shape isn't seekable or
  # the current row's sort key is ambiguous across a to-many join.
  #
  # The current row's own read and the two directional fetches are
  # three separate queries -- wrapped in a transaction so they share
  # one consistent snapshot (MySQL's default REPEATABLE READ). Without
  # this, a concurrent write to the current row's own sort columns
  # (e.g. another user's vote) landing between the reads could seed
  # the window from a value that's already stale by the later queries.
  def seek_window(current_id)
    cols = seekable_cols
    return nil unless cols

    model.transaction do
      current_row = current_sort_values(cols)
      current_row && build_window_around(cols, current_row, current_id)
    end
  end

  def build_window_around(cols, current_row, current_id)
    radius = window_radius
    before = window_leg_ids(cols, current_row, forward: false, radius:)
    after = window_leg_ids(cols, current_row, forward: true, radius:)
    { ids: before.reverse + [current_id] + after,
      offset: before.length,
      at_start: before.length < radius,
      at_end: after.length < radius }
  end

  # Ids on one side of the current row, closest first. Going backward,
  # the base scope's order is reversed so LIMIT lands on the rows
  # nearest the current tuple rather than the smallest tuples
  # satisfying the predicate.
  def window_leg_ids(cols, current_row, forward:, radius:)
    predicate = build_seek_predicate(cols, current_row, forward:)
    rel = scope.where(predicate)
    rel = rel.reverse_order unless forward
    rel.limit(radius).pluck(model.arel_table[:id])
  end

  # Fallback fill for order shapes the keyset predicate can't express,
  # and for an ambiguous current row: one full scan (today's
  # `result_ids`), sliced to the window before returning.
  def full_scan_window(current_id)
    ids = result_ids
    index = ids.index(current_id)
    return nil unless index

    radius = window_radius
    lo = [index - radius, 0].max
    hi = [index + radius, ids.length - 1].min
    { ids: ids[lo..hi], offset: index - lo,
      at_start: lo.zero?, at_end: hi == ids.length - 1 }
  end

  # `{ids:, offset:, at_start:, at_end:}` positioned at current_id,
  # from cache or a fresh compute -- or nil if current_id isn't in the
  # result set.
  def window_position
    cached_window_position || refresh_window
  end

  def cached_window_position
    return nil unless (key = window_cache_key)

    window = Rails.cache.read(key)
    return nil unless valid_window?(window)

    offset = window[:ids].index(current_id)
    return nil unless offset

    window.merge(offset:)
  end

  # A persistent, DB-backed cache (Solid Cache) can hand back an entry
  # written by a pre-deploy version of this code whose shape no longer
  # matches -- treat anything unexpected as a miss rather than raise.
  def valid_window?(window)
    window.is_a?(Hash) && window[:ids].is_a?(Array)
  end

  def refresh_window
    window = compute_window(current_id)
    return nil unless window

    if (key = window_cache_key)
      Rails.cache.write(key, window, expires_in: WINDOW_TTL)
    end
    window
  end

  # Serves prev/next from a cached or freshly-computed window.
  # Refetches when the lookup would run past a cached edge that isn't
  # the true edge of the result set -- distinct from being at the true
  # edge, which is a legitimate nil (no more results).
  #
  # Letter-paginated queries (`need_letters`) reorder at paginate time
  # in a way this module doesn't account for, and aren't cached or
  # seek-fetched.
  def windowed_id(dir)
    return legacy_windowed_id(dir) if need_letters

    window = window_position
    return nil unless window

    unless at_window_edge?(window, dir)
      id = boundary_id(window, dir)
      # A cached id can be destroyed after caching -- without this
      # check the arrow would point at a dead show page. Refetching
      # skips it and rewrites the cache: a fresh window is live data,
      # so its neighbor can't be a destroyed row.
      return id if model.exists?(id)
    end

    return nil if true_edge?(window, dir)

    window = refresh_window
    window ? boundary_id(window, dir) : nil
  end

  def legacy_windowed_id(dir)
    ids = result_ids
    index = ids.index(current_id)
    return nil unless index

    if dir == :prev
      ids[index - 1] if index.positive?
    elsif index < ids.length - 1
      ids[index + 1]
    end
  end

  def at_window_edge?(window, dir)
    dir == :prev ? window[:offset].zero? : last_offset?(window)
  end

  def true_edge?(window, dir)
    return window[:offset].zero? && window[:at_start] if dir == :prev

    last_offset?(window) && window[:at_end]
  end

  def last_offset?(window)
    window[:offset] == window[:ids].length - 1
  end

  def boundary_id(window, dir)
    return nil if true_edge?(window, dir)

    delta = dir == :prev ? -1 : 1
    window[:ids][window[:offset] + delta]
  end

  # No caching needed -- a direct LIMIT-1 query is already cheap and
  # order-shape-agnostic (works for aggregates/CASE/FIND_IN_SET too).
  # Falls back to result_ids for need_letters (see windowed_id), or
  # when it's already memoized -- reuses a caller's existing result
  # (e.g. search_controller's single-result redirect) instead of
  # firing another query.
  def edge_id(dir)
    return legacy_edge_id(dir) if need_letters || defined?(@result_ids)

    rel = dir == :first ? scope : scope.reverse_order
    rel.pick(model.arel_table[:id])
  end

  def legacy_edge_id(dir)
    dir == :first ? result_ids&.first : result_ids&.last
  end
end
