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
  # `options` (e.g. `expires_in:`) apply to the whole batch, read and
  # write alike -- captured here because the batched read happens
  # once, upfront, before any individual `fetch` call exists to carry
  # its own. `render_cached_boxes` has exactly one `low_level_cache`
  # call site today, so there's only one options value in play; a
  # `fetch(key, **options)` call still accepts (but doesn't use) its
  # own `options` to match Phlex's real cache_store interface.
  def initialize(real_store, keys, **options)
    @real_store = real_store
    @options = options
    @prefetched = keys.empty? ? {} : real_store.read_multi(*keys, **options)
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

    @real_store.write_multi(@pending_writes, **@options)
    @pending_writes = {}
  end
end
