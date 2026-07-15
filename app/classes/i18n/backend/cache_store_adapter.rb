# frozen_string_literal: true

# Thin #[]/#[]= adapter so an ActiveSupport::Cache::Store (SolidCache::Store,
# in our case) can be handed to I18n::Backend::KeyValue, which expects a
# store responding to #[]/#[]=/#keys (the Tokyo-Cabinet-style API it was
# originally designed around) rather than Rails' own #read/#write.
#
# #keys is intentionally NOT implemented -- Solid Cache doesn't support
# enumerating keys, and I18n::Backend::SolidCacheKeyValue overrides the
# one method (#available_locales) that would otherwise need it.
class I18n::Backend::CacheStoreAdapter
  def initialize(store)
    @store = store
  end

  def [](key)
    @store.read(key)
  end

  def []=(key, value)
    @store.write(key, value)
  end

  # Not part of KeyValue's own #[]/#[]= contract -- exposed so
  # LanguageExporter#strip (lib/tasks/lang.rake's strip step) can evict an
  # exact stripped tag's cache entry. Solid Cache has no delete_matched
  # (see #4807), only exact-key delete.
  delegate :delete, to: :@store
end
