# frozen_string_literal: true

require("test_helper")

class I18n::Backend::SolidCacheKeyValueTest < UnitTestCase
  def setup
    super
    @backend = I18n::Backend::SolidCacheKeyValue.new(
      I18n::Backend::CacheStoreAdapter.new(SolidCache::Store.new), false
    )
    @tag = :"_solid_cache_key_value_test_tag_#{object_id}"
  end

  def teardown
    @backend.delete_translation(:en, @tag)
    super
  end

  # Solid Cache can't enumerate keys; Chain unions every backend's own
  # available_locales, and DbFallback's DB-backed list is authoritative.
  def test_available_locales_is_always_empty
    assert_equal([], @backend.available_locales)
  end

  def test_delete_translation_evicts_the_stored_key
    @backend.store_translations(:en, { mo: { @tag => "hello" } })
    assert_equal("hello", @backend.send(:lookup, :en, "mo.#{@tag}"))

    @backend.delete_translation(:en, @tag)

    assert_nil(@backend.send(:lookup, :en, "mo.#{@tag}"))
  end

  # Pins the exact key format delete_translation assumes against what
  # KeyValue#store_translations/#lookup actually build the key as
  # (I18n::Backend::KeyValue::Implementation#store_translations:
  # `key = "#{locale}.#{key}"`) -- if the i18n gem's internal key
  # format ever changes, this breaks loudly instead of silently
  # leaving stale cache entries behind after Language::Exporter#strip.
  def test_delete_translation_uses_the_same_key_store_translations_writes
    @backend.store_translations(:en, { mo: { @tag => "hello" } })
    adapter = I18n::Backend::CacheStoreAdapter.new(SolidCache::Store.new)
    raw_key = "en.mo.#{@tag}"

    assert_not_nil(
      adapter[raw_key],
      "delete_translation's key format must match what " \
      "store_translations actually writes"
    )
  end
end
