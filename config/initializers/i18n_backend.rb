# frozen_string_literal: true

# MO's own translations (config.locale_namespace, "mo") are DB/Solid-Cache-
# backed (#4807) -- config/locales/*.yml for every locale stops being read
# at runtime. Keeping it on I18n.load_path here would let Rails' normal
# boot-time file loading overwrite fresh DB-sourced cache entries with a
# stale snapshot from whenever that .yml was last generated, on every
# single worker boot.
#
# Gem-provided translations (ActiveRecord/ActiveModel/ActionView/
# web-console/i18n's own plural rules -- confirmed the only gem-shipped
# locale files in this Gemfile) never live under config/locales, so this
# exclusion can't affect them; they still load normally into
# gem_file_backend below via the (now-filtered) I18n.load_path.
#
# after_initialize so I18n.load_path is fully populated by the i18n
# railtie (every engine's own config/locales, MO's included) before we
# filter it.
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
  gem_file_backend = I18n::Backend::Simple.new

  I18n.backend = I18n::Backend::Chain.new(
    cache_backend, db_fallback_backend, gem_file_backend
  )
end
