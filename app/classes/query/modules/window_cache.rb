# frozen_string_literal: true

##############################################################################
#
#  :module: WindowCache
#
#  Cached-window neighbor lookup for `Query::Modules::Sequence`, used as
#  an alternative to the bounded-query rewrite (`Query::Modules::Seek`,
#  #5115/#5117) -- keeps prev/next/first/last off the full `result_ids`
#  array by caching a window of ids around the current position, keyed
#  by `QueryRecord#id`. See #5101.
#
##############################################################################

module Query::Modules::WindowCache
  WINDOW_RADIUS = 504 # multiple of 12 -- ids kept on each side of current
  WINDOW_TTL = 30.minutes

  private

  def window_cache_key
    return nil unless record&.id

    "query_window/#{record.id}"
  end

  # Ids around `current_id`, `current_id`'s own index within them, and
  # whether each edge is the true edge of the full result set or just
  # where this window happens to stop -- or nil if `current_id` isn't
  # in the result set at all (deleted, no longer matches the filter).
  #
  # v1: one full scan (today's `result_ids`), sliced before returning.
  # A v2 could instead fetch only `WINDOW_RADIUS` rows per direction
  # via a keyset predicate (mirroring Query::Modules::Seek's
  # `seekable_order?`/`current_sort_values`/`build_seek_predicate`),
  # detecting `at_start`/`at_end` by whether that fetch came up short
  # of `WINDOW_RADIUS` rows -- everything below this method depends
  # only on the returned shape, not on how it was computed.
  def compute_window(current_id)
    ids = result_ids
    index = ids.index(current_id)
    return nil unless index

    lo = [index - WINDOW_RADIUS, 0].max
    hi = [index + WINDOW_RADIUS, ids.length - 1].min
    { ids: ids[lo..hi], offset: index - lo,
      at_start: lo.zero?, at_end: hi == ids.length - 1 }
  end

  # [ids, offset, at_start, at_end] positioned at current_id, from
  # cache or a fresh compute -- or nil if current_id isn't in the
  # result set at all.
  def window_position
    cached_window_position || refresh_window
  end

  def cached_window_position
    return nil unless (key = window_cache_key)

    window = Rails.cache.read(key)
    return nil unless window

    offset = window[:ids].index(current_id)
    return nil unless offset

    [window[:ids], offset, window[:at_start], window[:at_end]]
  end

  def refresh_window
    window = compute_window(current_id)
    return nil unless window

    Rails.cache.write(window_cache_key, window, expires_in: WINDOW_TTL) if
      window_cache_key
    [window[:ids], window[:offset], window[:at_start], window[:at_end]]
  end

  # Serves prev/next from a cached or freshly-computed window.
  # Refetches when the lookup would run past a cached edge that isn't
  # the true edge of the result set -- distinct from being at the true
  # edge, which is a legitimate nil (no more results).
  def windowed_id(dir)
    ids, offset, at_start, at_end = window_position
    return nil unless ids

    return boundary_id(ids, offset, at_start, at_end, dir) unless
      at_window_edge?(ids, offset, dir)

    if true_edge?(offset, at_start, at_end, ids, dir)
      nil
    else
      ids, offset, at_start, at_end = refresh_window
      return nil unless ids

      boundary_id(ids, offset, at_start, at_end, dir)
    end
  end

  def at_window_edge?(ids, offset, dir)
    dir == :prev ? offset.zero? : offset == ids.length - 1
  end

  def true_edge?(offset, at_start, at_end, ids, dir)
    return offset.zero? && at_start if dir == :prev

    offset == ids.length - 1 && at_end
  end

  def boundary_id(ids, offset, at_start, at_end, dir)
    return nil if true_edge?(offset, at_start, at_end, ids, dir)

    dir == :prev ? ids[offset - 1] : ids[offset + 1]
  end

  # No caching needed -- a direct LIMIT-1 query is already cheap and
  # order-shape-agnostic (works for aggregates/CASE/FIND_IN_SET too).
  def edge_id(dir)
    return nil if need_letters

    rel = dir == :first ? scope : scope.reverse_order
    rel.pick(model.arel_table[:id])
  end
end
