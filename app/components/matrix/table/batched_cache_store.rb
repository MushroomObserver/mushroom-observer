# frozen_string_literal: true

# Cache-store wrapper for one Matrix::Table#render_cached_boxes call.
# Phlex's `low_level_cache` calls `cache_store.fetch(key) { block }`
# once per object -- against the real store, that's one round trip
# per object (Solid Cache is DB-backed, so N objects means N SQL
# queries just to check cache status). This wrapper answers `fetch`
# from a single upfront `read_multi` instead, and batches every miss's
# write into one `write_multi` -- `low_level_cache` itself is
# unmodified, it just talks to this instead of the real store.
class Components::Matrix::Table::BatchedCacheStore
  def initialize(real_store, keys)
    @real_store = real_store
    @prefetched = keys.empty? ? {} : real_store.read_multi(*keys)
    @pending_writes = {}
  end

  def fetch(key, **_options)
    return @prefetched[key] if @prefetched.key?(key)

    value = yield
    @pending_writes[key] = value
    value
  end

  def flush_writes!
    return if @pending_writes.empty?

    @real_store.write_multi(@pending_writes)
  end
end
