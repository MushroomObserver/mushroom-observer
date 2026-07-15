# frozen_string_literal: true

class I18n::Backend::SolidCacheKeyValue < I18n::Backend::KeyValue
  # Solid Cache (like Redis/Memcached generally) doesn't support #keys --
  # KeyValue#available_locales/#translations both need @store.keys, which
  # would raise. Neither is meaningful for a pure cache layer anyway --
  # Chain unions every backend's #available_locales, and
  # I18n::Backend::DbFallback's DB-backed list is the authoritative one.
  def available_locales
    []
  end

  # Evicts one exact tag's cache entry for one locale -- used by
  # LanguageExporter#strip (lib/tasks/lang.rake), which knows exactly
  # which tags it's removing. Solid Cache has no delete_matched (#4807),
  # only exact-key delete -- verified empirically that a stored "mo:"
  # tag's key is "<locale>.<namespace>.<tag>" (matches lookup's own
  # normalize_flat_keys result for the same dotted string).
  def delete_translation(locale, tag)
    @store.delete("#{locale}.#{MO.locale_namespace}.#{tag}")
  end
end
