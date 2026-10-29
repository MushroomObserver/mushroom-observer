# frozen_string_literal: true

# MO's translations (config.locale_namespace, "mo") are DB/Solid-Cache-
# backed now -- excluding config/locales/*.yml from I18n.load_path
# stops Rails' boot-time file loading from overwriting fresh DB-sourced
# cache entries with a stale snapshot on every worker boot. Gem-provided
# translations live elsewhere, so this exclusion doesn't touch them.
# after_initialize so the i18n railtie has already populated
# I18n.load_path before this filters it.
Rails.application.config.after_initialize do
  I18n.load_path.reject! do |path|
    path.to_s.start_with?(Rails.root.join("config/locales").to_s)
  end

  # See I18n::Backend::CacheStoreSelector for why this is Rails.cache
  # (not a bare SolidCache::Store.new) with a NullStore fallback, rather
  # than either alone.
  cache_backend = I18n::Backend::SolidCacheKeyValue.new(
    I18n::Backend::CacheStoreAdapter.new(
      I18n::Backend::CacheStoreSelector.call
    ), false
  )
  db_fallback_backend = I18n::Backend::DbFallback.new(cache_backend)
  # See I18n::Backend::EnTxtLoader for why en.txt is loaded in here too.
  gem_file_backend = I18n::Backend::EnTxtLoader.call(I18n::Backend::Simple.new)

  I18n.backend = I18n::Backend::Chain.new(
    cache_backend, db_fallback_backend, gem_file_backend
  )
end
