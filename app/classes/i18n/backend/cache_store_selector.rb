# frozen_string_literal: true

# Picks the underlying store config/initializers/i18n_backend.rb hands
# to CacheStoreAdapter. Rails.cache in every environment except when it
# resolves to a no-op (ActiveSupport::Cache::NullStore -- e.g.
# config/environments/test.rb's config.cache_store = :null_store). The
# i18n cache backend is load-bearing (every I18n.t/.l call goes through
# it), unlike a disposable fragment cache, so it must not silently
# become a no-op: several tests (Language::ExporterTest, PatternSearchTest,
# HerbariumRecordTest) call I18n.backend.store_translations /
# TranslationString.store_localizations and then assert the write is
# visible through I18n.t -- a NullStore-backed cache would make that
# write vanish while leaving DbFallback + cache logic itself correct.
#
# In dev, Rails.cache resolves to :memory_store (an
# environment-appropriate override) -- see #4811 review: reaching
# around Rails.cache with a bare SolidCache::Store.new made every
# translation lookup a solid_cache_entries SQL query, even on a
# cache hit, in every environment including dev (191 queries loading
# /observations, flat across repeated loads, vs. 10 on main).
#
# Test env's fallback is MemoryStore, not SolidCache::Store:
# SolidCache::Entry is an AR model, so its writes roll back with each
# test's transaction, forcing every test to re-pay the DbFallback
# query. MemoryStore isn't transactional, so it stays warm for the
# worker's whole run.
class I18n::Backend::CacheStoreSelector
  def self.call(rails_cache: Rails.cache)
    if rails_cache.is_a?(ActiveSupport::Cache::NullStore)
      return ActiveSupport::Cache::MemoryStore.new
    end

    rails_cache
  end
end
