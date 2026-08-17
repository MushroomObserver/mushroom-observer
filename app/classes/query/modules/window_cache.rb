# frozen_string_literal: true

##############################################################################
#
#  :module: WindowCache
#
#  Cached-window neighbor lookup for `Query::Modules::Sequence`, used as
#  an alternative to the bounded-query rewrite (`Query::Modules::Seek`)
#  -- keeps prev/next/first/last off the full `result_ids` array by
#  caching a window of ids around the current position, keyed by
#  `QueryRecord#id`.
#
##############################################################################

module Query::Modules::WindowCache
  WINDOW_RADIUS = 504 # multiple of 12 -- ids kept on each side of current
  WINDOW_TTL = 30.minutes

  private

  # Scoped by viewer as well as QueryRecord -- `QueryRecord` dedups by
  # serialized query params only, so two different users browsing the
  # same logical query (e.g. everyone on the default unfiltered index)
  # would otherwise share one cache slot and continually evict each
  # other's window as they browse to different positions. No viewer
  # (a bot, or `create_query`'s callers that don't set one) means no
  # caching, rather than falling back to a shared anonymous slot.
  def window_cache_key
    return nil unless record&.id && viewer&.id

    "query_window/#{record.id}/#{viewer.id}"
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

  # `{ids:, offset:, at_start:, at_end:}` positioned at current_id,
  # from cache or a fresh compute -- or nil if current_id isn't in the
  # result set at all.
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
  # written by a pre-deploy version of this code if its shape ever
  # changes -- treat anything unexpected as a miss rather than raise.
  def valid_window?(window)
    window.is_a?(Hash) && window[:ids].is_a?(Array)
  end

  def refresh_window
    window = compute_window(current_id)
    return nil unless window

    Rails.cache.write(window_cache_key, window, expires_in: WINDOW_TTL) if
      window_cache_key
    window
  end

  # Serves prev/next from a cached or freshly-computed window.
  # Refetches when the lookup would run past a cached edge that isn't
  # the true edge of the result set -- distinct from being at the true
  # edge, which is a legitimate nil (no more results).
  #
  # Letter-paginated queries (`need_letters`) reorder at paginate time
  # in a way this module doesn't account for, and aren't cached --
  # same reason `Query::Modules::Seek#seek_or` bails on them.
  def windowed_id(dir)
    return legacy_windowed_id(dir) if need_letters

    window = window_position
    return nil unless window

    return boundary_id(window, dir) unless at_window_edge?(window, dir)

    if true_edge?(window, dir)
      nil
    else
      window = refresh_window
      window ? boundary_id(window, dir) : nil
    end
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
